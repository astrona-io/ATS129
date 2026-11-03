# Signers, Keys And Offline Verification

The signer decides who vouches for the statement. A key that never changes is a risk, and a key that changes without a plan breaks verification of everything signed before. This part reads the `x509` and `kms` signers, rotates the lab key, and verifies a payload from an annotation on a machine that has no access to the cluster.

## Two signers

`artifacts.taskrun.signer`, `artifacts.pipelinerun.signer` and `artifacts.oci.signer` take one of two values:

| Signer | Key lives in | Set up with |
| --- | --- | --- |
| `x509` (the default) | The Secret `signing-secrets`, or a certificate from Fulcio | A cosign key pair, an ed25519 or ecdsa key as `x509.pem`, or keyless |
| `kms` | A key management service | `signers.kms.kmsref` with a URI such as `gcpkms://`, `awskms://`, `azurekms://` or `hashivault://` |

With `x509` and a key in the Secret, Chains looks for `cosign.key` and `cosign.password`, or for an `x509.pem` file. The first form is the one `cosign generate-key-pair k8s://tekton-chains/signing-secrets` writes. With `kms`, the private key never leaves the service, and a rotation happens in the service, not in the cluster. The signer can differ per artifact type: images signed with `kms`, TaskRun provenance with `x509`.

## Read the key behind a signature

Every signed object points to the key that signed it by the public key you verify it with. Print the key currently in the Secret and its fingerprint:

<!-- astrona:playground:renew -->

```sh
kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data.cosign\.pub}' | base64 -d | tee current.pub
kubectl exec -n workstation deploy/workstation -- cosign public-key --key k8s://tekton-chains/signing-secrets
```

The two outputs are the same public key. Keep a copy of `current.pub`: it is what verifies every statement signed so far.

## Rotate the key

A rotation is a new key and a plan for the old statements. Chains reads the Secret when it starts, so the steps are in this order:

1. Save the old public key under a name with a date, such as `cosign-2026-11.pub`, where the verifiers can fetch it.
2. Make a new key pair. The Secret is immutable once `cosign` writes it, so delete it first:

```sh
kubectl delete secret signing-secrets -n tekton-chains
kubectl exec -n workstation deploy/workstation -- env COSIGN_PASSWORD=lab-only-password cosign generate-key-pair k8s://tekton-chains/signing-secrets
kubectl rollout restart deployment/tekton-chains-controller -n tekton-chains
kubectl rollout status deployment/tekton-chains-controller -n tekton-chains --timeout=300s
```

3. Build again. New runs are signed with the new key.
4. Tell verifiers to use the new public key for new artifacts and the old one for old artifacts.

Old statements stay valid against the old public key, and nothing re-signs them. A verifier that has only the new key rejects every old image. This is why a rotation needs a published list of keys, and why a KMS key with versions is easier to run: the key id stays and the versions change.

> [!WARNING]
> Deleting `signing-secrets` in a real cluster stops signing until the new Secret exists and the controller has restarted. Do it in a planned window, and never lose the old public key.

## Verify a payload without the cluster

An auditor with a copy of the annotations and the public key can check the signature on a laptop. Extract the two annotations of a TaskRun from the cluster:

```sh
TR="$(kubectl get taskrun -n starfleet -o jsonpath='{.items[-1].metadata.name}')"
UID_TR="$(kubectl get taskrun "$TR" -n starfleet -o jsonpath='{.metadata.uid}')"
kubectl get taskrun "$TR" -n starfleet -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/payload-taskrun-${UID_TR}}" | base64 -d > payload.json
kubectl get taskrun "$TR" -n starfleet -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-${UID_TR}}" | base64 -d > signature.bin
```

Copy `payload.json`, `signature.bin` and `current.pub` to the verifying machine. The Chains documentation verifies a signature of this kind with `cosign verify-blob-attestation`:

```sh
cosign verify-blob-attestation --key current.pub --signature signature.bin --type slsaprovenance1 --insecure-ignore-tlog --check-claims=false /dev/null
```

The command needs no access to the cluster or the registry. Use `--type slsaprovenance` for statements in the `in-toto` format. If your version of `cosign` reads the signature differently, the documentation of that version shows the flags, and you can always check the registry attestation with `cosign verify-attestation`, which reads everything from the image reference.

## Which signer for which job

1. A lab or a small team: `x509` with a cosign key pair in the Secret.
2. A team with a cloud account and a security team: `kms`, so that no private key sits in the cluster.
3. Many short-lived builders with an identity provider: keyless `x509` through Fulcio, from module one.
4. Images and provenance with different owners: set the signer per artifact type.

## Common pitfalls

> [!WARNING]
> - **Losing the old public key at a rotation.** Old artifacts then fail verification.
> - **Not restarting the controller.** It reads the Secret at start.
> - **Expecting a rotation to re-sign old runs.** Chains never touches a handled run.
> - **Putting a long-lived private key in a shared cluster.** Prefer `kms` where a service exists.
> - **Verifying with the wrong `--type`.** `slsaprovenance` is SLSA v0.2, `slsaprovenance1` is SLSA v1.0.
