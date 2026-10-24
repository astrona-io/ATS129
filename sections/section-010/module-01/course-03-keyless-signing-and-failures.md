# Keyless Signing, Transparency Logs And Quiet Failures

A key pair in a Secret works, but it is a long-lived secret. Anyone who reads `signing-secrets` can sign anything as your build system, and nobody would notice. Sigstore offers two answers: keyless signing, where every signature uses a short-lived certificate, and a public transparency log, where every signature is recorded so that misuse becomes visible. This part explains how Chains uses both, reads the provenance you stored, and shows how a signing setup fails without anyone noticing.

## Read the provenance in the attestation

Start with what you already have. `cosign verify-attestation` wrote the verified attestation to `attestation.json` in the workstation pod. Each line is a DSSE envelope (Dead Simple Signing Envelope, the JSON wrapper that holds a payload and its signature), and its `payload` field is the base64-encoded in-toto statement.

<!-- astrona:playground:renew -->

```sh
kubectl exec -n workstation deploy/workstation -- sh -c 'head -n 1 attestation.json | jq -r .payload | base64 -d | jq "{predicateType, subject, builder: .predicate.runDetails.builder, buildType: .predicate.buildDefinition.buildType}"'
```

The statement has `predicateType` `https://slsa.dev/provenance/v1`, one `subject` with the name `registry.localtest.me:5001/starfleet/bridge` and the `sha256` digest of the image, the builder ID `https://tekton.dev/chains/v2`, and the build type `https://tekton.dev/chains/v2/slsa`. The rest of the predicate lists the parameters of the run in `externalParameters`, the step images with their digests in `resolvedDependencies`, and the start and end time in `runDetails.metadata`. `chains-config` can change the builder ID with `builder.id` and the build type with `builddefinition.buildtype`.

## Keyless signing with Fulcio

Keyless signing replaces the long-lived private key with a short-lived certificate. Fulcio is the Sigstore certificate authority: it takes an OpenID Connect (OIDC) identity token, checks it, and issues a certificate that is valid for about ten minutes and names that identity. The signer creates a fresh key pair, gets the certificate for it, signs, and throws the private key away.

Chains gets its identity token from Kubernetes. The Deployment `tekton-chains-controller` already mounts a projected ServiceAccount token at `/var/run/sigstore/cosign/oidc-token`, with the audience `sigstore` and a lifetime of 600 seconds. These `chains-config` keys switch keyless signing on:

| Key | Default | Meaning |
| --- | --- | --- |
| `signers.x509.fulcio.enabled` | `false` | Use Fulcio certificates instead of the key in `signing-secrets` |
| `signers.x509.fulcio.address` | `https://fulcio.sigstore.dev` | The Fulcio server |
| `signers.x509.fulcio.issuer` | `https://oauth2.sigstore.dev/auth` | The expected OIDC issuer |
| `signers.x509.fulcio.provider` | unset (try each) | Where the token comes from: `google`, `spiffe`, `github` or `filesystem` |
| `signers.x509.identity.token.file` | unset | A file that holds the token |
| `signers.x509.tuf.mirror.url` | Sigstore's public TUF root | Where Chains fetches the Sigstore trust root |

The public Fulcio at `fulcio.sigstore.dev` accepts tokens from managed clusters such as EKS and GKE, but not from a `kind` cluster on a laptop. Keyless signing for a cluster like the playground needs a private Fulcio that trusts the cluster's ServiceAccount issuer. That is why the playground and the graded labs of this course sign with a key pair: the concepts are the same, and every check runs offline from public services.

A verifier of a keyless signature does not use a public key. It tells `cosign verify` which identity it expects with `--certificate-identity` and `--certificate-oidc-issuer`, and cosign checks the certificate chain against the Fulcio root.

## The transparency log: Rekor

Rekor is the Sigstore transparency log: an append-only, public record of signatures. When `transparency.enabled` is `true`, Chains uploads each signature to the log at `transparency.url` (default `https://rekor.sigstore.dev`) and writes the annotation `chains.tekton.dev/transparency` with the address of the log entry. With `manual`, Chains uploads only runs that carry the annotation `chains.tekton.dev/transparency-upload: "true"`. Keyless signing and the log belong together: the short-lived certificate is only useful if the log proves that the signature was made while the certificate was valid.

The log is public. Uploading publishes the names of your images and runs, so private builds often use a private Rekor or stay with `transparency.enabled: "false"`, as this course does. That is also why every `cosign` command here needs `--insecure-ignore-tlog`.

The third option is a key in a key management service. `artifacts.*.signer: kms` and `signers.kms.kmsref` point Chains at a key in Google Cloud KMS (`gcpkms://`), AWS KMS (`awskms://`), Azure Key Vault (`azurekms://`) or HashiCorp Vault and OpenBao Transit (`hashivault://`). The private key never leaves the service, and Chains needs credentials for it instead of a key file.

## Watch a setup fail quietly

Every failure of Chains stays off the TaskRun's status, so learn its signs. Remove the insecure-registry setting and build again:

```sh
kubectl patch configmap chains-config -n tekton-chains --type json -p '[{"op":"remove","path":"/data/storage.oci.repository.insecure"}]'
tkn task start build-image -n starfleet -p image=registry.localtest.me:5001/starfleet/scout -p tag=1.0.0 --prefix-name build-scout --showlog
```

The run succeeds. Now watch the annotations of the newest run for a minute or two:

```sh
RUN=$(kubectl get taskruns -n starfleet --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
kubectl get taskrun "$RUN" -n starfleet -o yaml | grep 'chains.tekton.dev/'
kubectl logs -n tekton-chains deploy/tekton-chains-controller --since=5m | grep -i https
```

Chains signed the payloads, but the push to the registry failed with `http: server gave HTTP response to HTTPS client`. The controller counts its attempts in `chains.tekton.dev/retries`, and after three retries it sets `chains.tekton.dev/signed: "failed"`. It never tries that run again. Put the setting back before you go on:

```sh
kubectl patch configmap chains-config -n tekton-chains --type merge -p '{"data":{"storage.oci.repository.insecure":"true"}}'
```

There are three quiet failures to remember, and each one shows up in a different place:

| What went wrong | Annotation | Where you see it |
| --- | --- | --- |
| No key, or a wrong `cosign.password` | `signed: "true"` | Controller log: no signer configured; nothing in the registry |
| No type-hinting results, or a digest without `sha256:` | `signed: "true"` | Run results; controller log; no `.sig` tag |
| Storage unreachable (TLS, permissions, network) | `retries`, then `signed: "failed"` | Controller log: the push error |

You can now read the provenance Chains stored, explain keyless signing with Fulcio and the Rekor log, name the KMS option, and find the three ways a signing setup fails without failing the run. The check that never lies is `cosign verify` against the registry.

## Common pitfalls

> [!WARNING]
> - **Turning on the public log by accident.** `transparency.enabled: "true"` publishes the names of your images. Use a private Rekor or keep it off.
> - **Expecting keyless signing to work on any cluster.** The public Fulcio trusts only some OIDC issuers. A `kind` cluster needs a private Fulcio.
> - **Verifying keyless signatures with `--key`.** Keyless signatures have no public key; pass the expected identity and issuer instead.
> - **Waiting for a failed run to be retried.** After `signed: "failed"` Chains is done with that run. Fix the cause and start a new run.
> - **Reading only the first line of the log.** The signer error and the push error come from different steps; search the log for both.

## Your mission: Sign Built Images With Tekton Chains

You can now give Chains a key, configure where it stores signatures and provenance, write the type-hinting results, and verify the result with `cosign`. The graded lab gives you an installation where the TaskRun says "signed" but nothing is, and asks you to set up signing so that every build of the Task is signed and attested in the registry.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-129-playground-010-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-010/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-129-lab-010-01
astrona start ats-129-playground-010-01
```
