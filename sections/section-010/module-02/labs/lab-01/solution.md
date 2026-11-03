# Solution: Choose Chains Provenance Format And Storage

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: `signing-secrets` still holds the key; `chains-config` has the format and both storage backends; `build-bridge` holds a signed SLSA v1.0 payload in its annotations; and the image of `build-bridge` and of a new grader build verify with `cosign`.

## Step 1: Read the current state

```sh
kubectl get configmap chains-config -n tekton-chains -o jsonpath='{.data}{"\n"}'
kubectl get taskrun build-bridge -n starfleet -o yaml | grep 'chains.tekton.dev/'
```

`chains-config` holds no `artifacts.taskrun.*` key, so the defaults apply: the format `in-toto` and the storage `tekton`. The annotations hold a payload and a signature, and no attestation is in the registry.

## Step 2: Change the format and the storage

Save this as `configmap-chains-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: chains-config
  namespace: tekton-chains
data:
  artifacts.taskrun.format: slsa/v2alpha4
  artifacts.taskrun.storage: tekton,oci
  artifacts.oci.storage: oci
  transparency.enabled: "false"
  storage.oci.repository.insecure: "true"
```

Apply it:

```sh
kubectl apply -f configmap-chains-config.yaml
```

List all five keys. The starting state was applied with `kubectl apply`, and a later `kubectl apply` removes the keys that the earlier file set and the new file leaves out.

## Step 3: Run the build again

Chains handles a finished run once, so the old run keeps its old provenance. Create it again:

```sh
kubectl delete taskrun build-bridge -n starfleet
cat <<'YAML' | kubectl apply -f -
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
YAML
kubectl wait --for=condition=Succeeded taskrun/build-bridge -n starfleet --timeout=300s
```

## Step 4: Check the result

Wait until the annotation is `true`, then read the payload and verify the attestation:

```sh
kubectl get taskrun build-bridge -n starfleet -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}{"\n"}'
UID_TR="$(kubectl get taskrun build-bridge -n starfleet -o jsonpath='{.metadata.uid}')"
kubectl get taskrun build-bridge -n starfleet -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/payload-taskrun-${UID_TR}}" | base64 -d | jq '.predicateType'
```

The predicate type is `https://slsa.dev/provenance/v1`. Verify the attestation in the registry with the public key:

```sh
kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data.cosign\.pub}' | base64 -d > cosign.pub
DIGEST="$(kubectl get taskrun build-bridge -n starfleet -o jsonpath='{.status.results[?(@.name=="IMAGE_DIGEST")].value}')"
kubectl exec -i -n workstation deploy/workstation -- sh -c 'cat > /tmp/cosign.pub' < cosign.pub
kubectl exec -n workstation deploy/workstation -- cosign verify-attestation --key /tmp/cosign.pub --insecure-ignore-tlog --allow-http-registry --type slsaprovenance1 "registry.localtest.me:5001/starfleet/bridge@${DIGEST}" > /dev/null
```

The last command prints verification lines on standard error and exits with `0` when it passes.

## Why this works

`artifacts.taskrun.format` decides the shape of the statement, and `artifacts.taskrun.storage` decides where Chains writes it. A comma-separated list writes it to every backend named. Chains reads `chains-config` when it handles a run, so a new run picks up the change.
