# Sign Images And Store Attestations In A Registry

Provenance stored on a TaskRun helps the cluster administrator, but not the people who pull the image. They see only the registry, and TaskRuns are often deleted after a few days. For them, the signature and the provenance must sit in the registry, next to the image. This part makes Chains do that: a Task reports which image it built, Chains signs the image and pushes a provenance attestation, and `cosign` verifies both.

## Tell Chains which image a run built

Chains cannot look inside a step to see what it pushed. Instead, it reads the results of the run and looks for names it knows. This is called type hinting. For one image, the Task writes two results whose names end in `IMAGE_URL` and `IMAGE_DIGEST`:

| Result name | Value | Example |
| --- | --- | --- |
| `IMAGE_URL` (or `<prefix>-IMAGE_URL`) | The image reference, with or without a tag | `registry.localtest.me:5001/starfleet/bridge:1.0.0` |
| `IMAGE_DIGEST` (or `<prefix>-IMAGE_DIGEST`) | The digest, with its algorithm | `sha256:` followed by 64 hexadecimal characters |
| `IMAGES` | Several `image@sha256:...` references, separated by commas | |
| `<prefix>-ARTIFACT_OUTPUTS` | An object result with the keys `uri` and `digest` | |

Chains turns each pair into the reference `<IMAGE_URL>@<IMAGE_DIGEST>`. If the digest has no `sha256:` prefix, that reference is invalid and Chains skips the image. Results named `CHAINS-GIT_URL` and `CHAINS-GIT_COMMIT` work the same way for inputs: they put the source repository and commit into the provenance.

The Task below builds a tiny image from scratch with `regctl`, pushes it to the lab registry, and writes the two type-hinting results. Building a real application image would need a build tool, but for Chains only the pushed image and its digest matter.

<!-- astrona:playground:renew -->

Save this as `task-build-image.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: build-image
  namespace: starfleet
spec:
  params:
    - name: image
      type: string
      description: Repository of the image, without a tag
    - name: tag
      type: string
      default: "1.0.0"
  results:
    - name: IMAGE_URL
      description: The image that was pushed, with its tag
    - name: IMAGE_DIGEST
      description: The digest of the pushed image
  steps:
    - name: build-and-push
      image: ghcr.io/regclient/regctl:v0.11.7-alpine
      script: |
        #!/bin/sh
        set -eu
        registry="$(echo "$(params.image)" | cut -d/ -f1)"
        regctl --host "reg=${registry},tls=disabled" image create "$(params.image):$(params.tag)" \
          --label "dev.tekton.taskrun=$(context.taskRun.name)"
        digest="$(regctl --host "reg=${registry},tls=disabled" image digest "$(params.image):$(params.tag)")"
        printf '%s' "$(params.image):$(params.tag)" | tee "$(results.IMAGE_URL.path)"
        echo
        printf '%s' "$digest" | tee "$(results.IMAGE_DIGEST.path)"
```

Apply it:

```sh
kubectl apply -f task-build-image.yaml
```

## Store signatures and attestations in the registry

The default `chains-config` keeps TaskRun provenance on the TaskRun. Three settings move it to the registry and switch it to SLSA v1.0. An attestation is a signed in-toto statement about an artifact; Chains stores it in the registry as an OCI artifact next to the image.

| Key | Value | Effect |
| --- | --- | --- |
| `artifacts.taskrun.format` | `slsa/v2alpha4` | Provenance in the SLSA v1.0 format |
| `artifacts.taskrun.storage` | `oci` | Push the TaskRun attestation to the registry, next to the image it names |
| `artifacts.oci.storage` | `oci` | Push the image signature to the registry (this is the default) |
| `transparency.enabled` | `"false"` | No upload to a transparency log (this is the default) |
| `storage.oci.repository.insecure` | `"true"` | Allow a registry without a valid TLS certificate, lab-only |

The format names are confusing, so learn the mapping: `in-toto` and its alias `slsa/v1` write SLSA v0.2 provenance; `slsa/v2alpha3` and `slsa/v2alpha4` write SLSA v1.0 provenance. `slsa/v2alpha4` also reads type-hinted results of StepActions. The storage keys accept a comma-separated list: `tekton`, `oci`, `gcs`, `docdb`, `grafeas` and `archivista`, so `tekton,oci` stores in both places.

The last key exists for labs only. The registry name `registry.localtest.me` is not a local name, so the Chains controller talks HTTPS to it, and the lab registry speaks plain HTTP. With `storage.oci.repository.insecure: "true"`, the controller also accepts plain HTTP and skips TLS certificate checks. Never set it for a real registry: an attacker between Chains and the registry could change the provenance.

Save this as `configmap-chains-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: chains-config
  namespace: tekton-chains
data:
  artifacts.taskrun.format: slsa/v2alpha4
  artifacts.taskrun.storage: oci
  artifacts.oci.storage: oci
  transparency.enabled: "false"
  storage.oci.repository.insecure: "true"
```

Apply it:

```sh
kubectl apply -f configmap-chains-config.yaml
```

The Chains controller watches `chains-config` and uses the new values for the next run it handles; no restart is needed.

## Build, then verify with cosign

Start a build of the image `bridge`. The command needs the key from earlier in `signing-secrets`; without a key, nothing is signed.

```sh
tkn task start build-image -n starfleet -p image=registry.localtest.me:5001/starfleet/bridge -p tag=1.0.0 --prefix-name build-bridge --showlog
```

The log ends with the image reference and its digest. Read the newest run's annotation and digest:

```sh
RUN=$(kubectl get taskruns -n starfleet --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
kubectl get taskrun "$RUN" -n starfleet -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}{"\n"}{.status.results[?(@.name=="IMAGE_DIGEST")].value}{"\n"}'
```

The annotation is `true` and the digest starts with `sha256:`. Now check the registry from the workstation pod. Replace `<DIGEST>` with the digest you just read:

```sh
kubectl exec -it -n workstation deploy/workstation -- sh
IMAGE=registry.localtest.me:5001/starfleet/bridge:1.0.0@<DIGEST>
regctl tag ls registry.localtest.me:5001/starfleet/bridge
cosign verify --key k8s://tekton-chains/signing-secrets --insecure-ignore-tlog --allow-http-registry "$IMAGE"
cosign verify-attestation --key k8s://tekton-chains/signing-secrets --insecure-ignore-tlog --allow-http-registry --type slsaprovenance1 "$IMAGE" > attestation.json
exit
```

`regctl tag ls` lists `1.0.0` and two tags built from the digest: `sha256-<hex>.sig` holds the image signature and `sha256-<hex>.att` holds the attestation. This is the classic cosign storage layout, which Chains uses by default (`storage.oci.encoding-format: dsse`). `cosign verify` checks the signature against `cosign.pub` from the Secret and prints the signed payload. `cosign verify-attestation` checks the attestation and that its `predicateType` is SLSA v1.0 (`slsaprovenance1`); for the SLSA v0.2 formats you would pass `slsaprovenance`. Both need `--insecure-ignore-tlog` because nothing went to a transparency log, and `--allow-http-registry` because the registry speaks plain HTTP.

Look at what verifying proved. Anyone with `cosign.pub` can now check that this exact digest was signed by your Chains installation, and read how it was built. They never needed access to the cluster or the TaskRun. What they cannot see yet is whether the signing key itself can be trusted, and what happens when it is lost: the open question is how to sign without a long-lived key.

## Common pitfalls

> [!WARNING]
> - **Results with the wrong names.** `url` or `digest` mean nothing to Chains. The names must end in `IMAGE_URL` and `IMAGE_DIGEST`.
> - **A digest without `sha256:`.** Chains cannot build a valid reference and skips the image, while still marking the run as signed.
> - **Mixing up the formats.** `in-toto` and `slsa/v1` are SLSA v0.2; `slsa/v2alpha3` and `slsa/v2alpha4` are SLSA v1.0. Pass the matching `--type` to `cosign verify-attestation`.
> - **Storage left on `tekton`.** The provenance then stays on the TaskRun, and `cosign verify-attestation` finds nothing in the registry.
> - **A plain-HTTP registry without `storage.oci.repository.insecure`.** The push fails, Chains retries, and in the end marks the run `failed`.
