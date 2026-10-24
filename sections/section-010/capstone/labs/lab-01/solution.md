# Solution: Repair A Broken Signing Setup

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: `signing-secrets` still holds the release key with the right password; `chains-config` stores SLSA v1.0 attestations and signatures in the plain-HTTP registry; `release-shuttle` succeeded and verifies with the release public key; and a new release by the grader verifies too.

The three faults show one after the other. Each fix needs a new TaskRun, because Tekton Chains handles every TaskRun only once.

## Step 1: Prove that nothing is signed

Open a shell in the workstation pod and try to verify the release with the public key from the ConfigMap `release-key`:

```sh
kubectl exec -it -n workstation deploy/workstation -- sh
regctl tag ls registry.localtest.me:5001/starfleet/shuttle
cosign verify --key k8s://tekton-chains/signing-secrets --insecure-ignore-tlog --allow-http-registry registry.localtest.me:5001/starfleet/shuttle:2.0.0
exit
```

The registry has only the tag `2.0.0`, no `.sig` or `.att` tag, and `cosign verify` fails because it finds no signature. The annotation `chains.tekton.dev/signed: "true"` on the TaskRun is not proof.

## Step 2: Fault 1, the key password

Read the Chains controller log:

```sh
kubectl logs -n tekton-chains deploy/tekton-chains-controller | grep -i -E 'signer|decrypt'
```

The controller logs `error configuring x509 signer` with an error about decrypting the key, and then `No signer x509 configured`. The key pair is there, but `cosign.password` does not open `cosign.key`. Without a signer, Chains v0.29.9 skips the signing and still marks the run as signed.

Read the escrowed password and put it into `signing-secrets`. The task forbids a new key pair, so patch only the password:

```sh
kubectl get secret release-key-escrow -n starfleet -o jsonpath='{.data.password}' | base64 -d; echo
kubectl patch secret signing-secrets -n tekton-chains --type merge -p '{"stringData":{"cosign.password":"release-2026-lab-only"}}'
kubectl rollout restart deployment/tekton-chains-controller -n tekton-chains
kubectl rollout status deployment/tekton-chains-controller -n tekton-chains
```

The first command prints `release-2026-lab-only`. The restart makes the controller see the changed Secret volume at once.

Run the release again under the same name. Save this as `taskrun-release-shuttle.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: release-shuttle
  namespace: starfleet
spec:
  taskRef:
    name: release-image
  params:
    - name: image
      value: registry.localtest.me:5001/starfleet/shuttle
    - name: tag
      value: "2.0.0"
```

Apply it:

```sh
kubectl delete taskrun release-shuttle -n starfleet
kubectl apply -f taskrun-release-shuttle.yaml
kubectl wait --for=condition=Succeeded taskrun/release-shuttle -n starfleet --timeout=180s
```

## Step 3: Fault 2, the digest result

The registry still has no `.sig` tag. Look at the results and the log:

```sh
kubectl get taskrun release-shuttle -n starfleet -o jsonpath='{range .status.results[*]}{.name}={.value}{"\n"}{end}'
kubectl logs -n tekton-chains deploy/tekton-chains-controller --since=5m | grep -i -E 'digest|subject'
```

`IMAGE_DIGEST` is 64 hexadecimal characters without the `sha256:` prefix. Chains builds `<IMAGE_URL>@<IMAGE_DIGEST>`, cannot parse it as a digest reference, logs `error getting digest`, and finds no image to sign. The attestation has no subject, so the OCI storage backend skips the upload (`No image subject to attest`).

The script of the Task strips the prefix with `${digest#sha256:}`. Save this as `task-release-image.yaml`, which writes the digest unchanged:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: release-image
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

Apply it, and run the release again:

```sh
kubectl apply -f task-release-image.yaml
kubectl delete taskrun release-shuttle -n starfleet
kubectl apply -f taskrun-release-shuttle.yaml
kubectl wait --for=condition=Succeeded taskrun/release-shuttle -n starfleet --timeout=180s
```

## Step 4: Fault 3, the plain-HTTP registry

Wait a minute and read the annotations:

```sh
kubectl get taskrun release-shuttle -n starfleet -o jsonpath='{.metadata.annotations}{"\n"}'
kubectl logs -n tekton-chains deploy/tekton-chains-controller --since=5m | grep -i https
```

Now Chains signs, but the push fails: the log shows `http: server gave HTTP response to HTTPS client`. Chains counts the attempts in `chains.tekton.dev/retries` and, after three retries, sets `chains.tekton.dev/signed: "failed"`. The name `registry.localtest.me` is not a local name, so Chains uses HTTPS unless `chains-config` allows an insecure registry:

```sh
kubectl patch configmap chains-config -n tekton-chains --type merge -p '{"data":{"storage.oci.repository.insecure":"true"}}'
kubectl delete taskrun release-shuttle -n starfleet
kubectl apply -f taskrun-release-shuttle.yaml
kubectl wait --for=condition=Succeeded taskrun/release-shuttle -n starfleet --timeout=180s
```

## Step 5: Verify with the release key

Read the digest, then verify in the workstation pod with the key from `signing-secrets`, which is now the release key with the right password (`<DIGEST>` is the `sha256:...` value):

```sh
kubectl get taskrun release-shuttle -n starfleet -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}{"\n"}{.status.results[?(@.name=="IMAGE_DIGEST")].value}{"\n"}'
kubectl exec -it -n workstation deploy/workstation -- sh
IMAGE=registry.localtest.me:5001/starfleet/shuttle:2.0.0@<DIGEST>
cosign verify --key k8s://tekton-chains/signing-secrets --insecure-ignore-tlog --allow-http-registry "$IMAGE"
cosign verify-attestation --key k8s://tekton-chains/signing-secrets --insecure-ignore-tlog --allow-http-registry --type slsaprovenance1 "$IMAGE"
```

The annotation is `true`, and both `cosign` commands end with exit code 0.

## Step 6: Submit

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Run `cosign generate-key-pair k8s://tekton-chains/signing-secrets` again | The release key is replaced; customers' public key no longer verifies, and the grader rejects it |
| Sign the image by hand in the workstation | The grader's own release stays unsigned |
| Remove `artifacts.oci.storage` or set the signer to `none` | Nothing is signed, so `cosign verify` fails |
| Change only the old TaskRun's annotation | Chains never handles a TaskRun twice; only a new run is signed |
| Turn on `transparency.enabled` | Chains tries to reach the public Rekor log, which the lab does not use |

## Common mistakes

- Fixing one fault and checking the annotation instead of the registry. After fault 1 and fault 2 the annotation can still say `true` while nothing was pushed.
- Forgetting that a Secret volume refreshes only after a delay. Restart the controller, or wait about a minute, before the next run.
- Typing the password with a trailing newline into the Secret. Patch it with `stringData` as above.

## Practice on your own

- Read the `chains.tekton.dev/retries` annotation on a run that failed to push, and count the attempts.
- Decode the attestation and compare its `subject` digest with `IMAGE_DIGEST`.
- Store the attestation in both `tekton` and `oci` storage, and read it back with `tkn chain payload`.
