# Solution: Sign Built Images With Tekton Chains

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: `signing-secrets` holds a cosign key pair; `chains-config` has the five settings from the task; `build-bridge` succeeded and its image signature and SLSA v1.0 provenance verify with `cosign.pub`; and a new build of `build-image` is signed and attested too.

## Step 1: See why "signed" means nothing yet

Read the annotation and the results of the TaskRun:

```sh
kubectl get taskrun build-bridge -n starfleet -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}{"\n"}{range .status.results[*]}{.name}={.value}{"\n"}{end}'
```

The annotation is `true`, and the results are called `url` and `digest`. Now look at what the Chains controller logged for this run:

```sh
kubectl logs -n tekton-chains deploy/tekton-chains-controller | grep -i -E 'signer|build-bridge'
```

The controller found no private key in `signing-secrets` (`no valid private key found`), skipped every signature, and still marked the run as signed. In Tekton Chains v0.29.9 a missing signer is not an error, so the annotation alone proves nothing. Only `cosign verify` against the registry does.

## Step 2: Create the key pair

Open a shell in the workstation pod:

```sh
kubectl exec -it -n workstation deploy/workstation -- sh
```

Inside it, create the key pair straight into the Secret. `COSIGN_PASSWORD` sets the password that encrypts the private key, so `cosign` does not prompt:

```sh
COSIGN_PASSWORD=lab-only-password cosign generate-key-pair k8s://tekton-chains/signing-secrets
```

`cosign` writes `cosign.key`, `cosign.password` and `cosign.pub` into `signing-secrets`, marks the Secret immutable, and saves `cosign.pub` in the current folder. Leave the shell with `exit`.

## Step 3: Configure Chains

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

The Chains controller watches this ConfigMap and uses the new values for the next run it signs.

## Step 4: Fix the type-hinting results

Chains looks for a pair of results whose names end in `IMAGE_URL` and `IMAGE_DIGEST`. The Task calls them `url` and `digest`, so Chains finds no image to sign.

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
      description: Repository of the image, without a tag (registry.localtest.me:5001/starfleet/<name>)
    - name: tag
      type: string
      description: Tag to push
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
        # The lab registry speaks plain HTTP, so tell regctl not to use TLS.
        regctl --host "reg=${registry},tls=disabled" image create "$(params.image):$(params.tag)" \
          --label "org.opencontainers.image.version=$(params.tag)" \
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

## Step 5: Restart the controller and build again

The Chains controller reads the key files from a Secret volume. The kubelet refreshes that volume within about a minute; a restart makes the controller see the new key at once:

```sh
kubectl rollout restart deployment/tekton-chains-controller -n tekton-chains
kubectl rollout status deployment/tekton-chains-controller -n tekton-chains
```

Chains never handles a TaskRun twice, and `build-bridge` already carries its annotation. Delete it and create it again from the same values.

Save this as `taskrun-build-bridge.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: build-bridge
  namespace: starfleet
spec:
  taskRef:
    name: build-image
  params:
    - name: image
      value: registry.localtest.me:5001/starfleet/bridge
    - name: tag
      value: "1.0.0"
```

Apply it:

```sh
kubectl delete taskrun build-bridge -n starfleet
kubectl apply -f taskrun-build-bridge.yaml
kubectl wait --for=condition=Succeeded taskrun/build-bridge -n starfleet --timeout=180s
```

Then check the result:

```sh
kubectl get taskrun build-bridge -n starfleet -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}{"\n"}{.status.results[?(@.name=="IMAGE_DIGEST")].value}{"\n"}'
```

The annotation is `true` again, and the digest starts with `sha256:`.

## Step 6: Verify with cosign

Open the workstation shell again and set `IMAGE` to the reference with the digest from the last command (`<DIGEST>` is the `sha256:...` value):

```sh
kubectl exec -it -n workstation deploy/workstation -- sh
IMAGE=registry.localtest.me:5001/starfleet/bridge:1.0.0@<DIGEST>
regctl tag ls registry.localtest.me:5001/starfleet/bridge
cosign verify --key k8s://tekton-chains/signing-secrets --insecure-ignore-tlog --allow-http-registry "$IMAGE"
cosign verify-attestation --key k8s://tekton-chains/signing-secrets --insecure-ignore-tlog --allow-http-registry --type slsaprovenance1 "$IMAGE"
```

`regctl tag ls` lists `1.0.0` plus two tags named after the digest, ending in `.sig` and `.att`: the signature and the attestation that Chains pushed. Both `cosign` commands end with exit code 0. `--insecure-ignore-tlog` is needed because Chains uploaded nothing to a transparency log.

## Step 7: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Trust `chains.tekton.dev/signed: "true"` | Chains sets it even when it had no key; the grader verifies with `cosign` |
| Sign the image by hand with `cosign sign` | `build-bridge` is not attested and the grader's own build stays unsigned |
| Rename the results in the TaskRun only | Results come from the Task; the grader's new run uses the Task |
| Keep `artifacts.taskrun.storage: tekton` | The provenance lands in TaskRun annotations, not in the registry, so `cosign verify-attestation` finds nothing |
| Leave out `storage.oci.repository.insecure` | Chains tries HTTPS against the plain-HTTP registry, the push fails, and after three retries the run is marked `failed` |
| Turn on `transparency.enabled` | Chains tries to reach the public Rekor log, which the lab does not use |

## Common mistakes

- Expecting the old `build-bridge` to be signed after the fix. Chains handles each TaskRun once; create a new run.
- Using `slsaprovenance` instead of `slsaprovenance1` with `cosign verify-attestation`. The first is SLSA v0.2, which Chains writes for `in-toto` and `slsa/v1`.
- Running `cosign generate-key-pair` a second time. The Secret is now immutable; delete it first if you really need a new key.

## Practice on your own

- Decode the attestation with `cosign verify-attestation ... | jq -r .payload | base64 -d | jq .predicate.buildDefinition` and find the parameters of the run.
- Set `artifacts.taskrun.storage` to `tekton,oci`, build again, and read the `chains.tekton.dev/payload-taskrun-<uid>` annotation.
- Point `cosign verify` at a different public key and read the error.
