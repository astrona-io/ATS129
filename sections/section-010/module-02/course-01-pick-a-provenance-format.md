# Pick A Provenance Format

Provenance is a statement about a build: which run made it, with which inputs, and who vouches for it. Chains can write that statement in more than one shape. The shape decides which tools can read it and which fields an auditor finds. This part sets up a signing key, builds one image, and writes the provenance of that build in two formats, so that you can compare the statements field by field.

## Set up the playground

The playground has no key and no Task. Create the key, a minimal `chains-config`, and a Task that reports the image it pushed:

<!-- astrona:playground:renew -->

```sh
kubectl exec -n workstation deploy/workstation -- env COSIGN_PASSWORD=lab-only-password cosign generate-key-pair k8s://tekton-chains/signing-secrets
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: chains-config
  namespace: tekton-chains
data:
  artifacts.oci.storage: oci
  transparency.enabled: "false"
  storage.oci.repository.insecure: "true"
YAML
cat <<'YAML' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: build-image
  namespace: starfleet
spec:
  params:
    - name: image
    - name: tag
      default: "1.0.0"
  results:
    - name: IMAGE_URL
    - name: IMAGE_DIGEST
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
        printf '%s' "$(params.image):$(params.tag)" > "$(results.IMAGE_URL.path)"
        printf '%s' "$digest" > "$(results.IMAGE_DIGEST.path)"
YAML
kubectl rollout restart deployment/tekton-chains-controller -n tekton-chains
kubectl rollout status deployment/tekton-chains-controller -n tekton-chains --timeout=300s
```

The Secret is created by `cosign` in the workstation pod, whose ServiceAccount may write to `tekton-chains`. The restart makes the controller mount the new key at once.

## The four formats

`artifacts.taskrun.format` accepts four values:

| Value | SLSA version | `predicateType` |
| --- | --- | --- |
| `in-toto` | v0.2 | `https://slsa.dev/provenance/v0.2` |
| `slsa/v1` | v0.2, an alias of `in-toto` | `https://slsa.dev/provenance/v0.2` |
| `slsa/v2alpha3` | v1.0 | `https://slsa.dev/provenance/v1` |
| `slsa/v2alpha4` | v1.0 | `https://slsa.dev/provenance/v1` |

The name `slsa/v1` is a trap: it writes the older SLSA v0.2 statement. The two `v2alpha` formats write SLSA v1.0, and the `alpha` in the name says that their fields can still change between Chains releases. Check the Chains release notes before you upgrade a cluster that depends on one.

## Build once, in the default format

Run the Task with the defaults. The format is `in-toto` because no `artifacts.taskrun.format` key is set:

```sh
tkn task start build-image -n starfleet --param image=registry.localtest.me:5001/starfleet/crew --param tag=1.0.0 --showlog
```

Wait until the annotation says `true`, then decode the payload:

```sh
kubectl get taskrun -n starfleet -o jsonpath='{.items[0].metadata.annotations.chains\.tekton\.dev/signed}{"\n"}'
TR="$(kubectl get taskrun -n starfleet -o jsonpath='{.items[0].metadata.name}')"
UID_TR="$(kubectl get taskrun "$TR" -n starfleet -o jsonpath='{.metadata.uid}')"
kubectl get taskrun "$TR" -n starfleet -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/payload-taskrun-${UID_TR}}" | base64 -d | jq '{_type, predicateType, subject: .subject[0].name, builder: .predicate.builder.id, buildType: .predicate.buildType}'
```

The statement has the type `https://in-toto.io/Statement/v0.1`, the `predicateType` of SLSA v0.2, and the fields `builder.id` and `buildType` directly under `predicate`. The `subject` lists the image. In SLSA v0.2 the inputs are under `invocation` and `materials`.

## Change the format and build again

Add one key to `chains-config`:

```sh
kubectl patch configmap chains-config -n tekton-chains --type merge -p '{"data":{"artifacts.taskrun.format":"slsa/v2alpha4"}}'
tkn task start build-image -n starfleet --param image=registry.localtest.me:5001/starfleet/crew --param tag=1.0.1 --showlog
```

The older run keeps its old statement, because Chains never rewrites a run it has handled. Decode the payload of the new run the same way, and read the SLSA v1.0 fields:

```sh
TR="$(kubectl get taskrun -n starfleet --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')"
UID_TR="$(kubectl get taskrun "$TR" -n starfleet -o jsonpath='{.metadata.uid}')"
kubectl get taskrun "$TR" -n starfleet -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/payload-taskrun-${UID_TR}}" | base64 -d | jq '{predicateType, builder: .predicate.runDetails.builder.id, buildType: .predicate.buildDefinition.buildType, started: .predicate.runDetails.metadata.startedOn}'
```

In SLSA v1.0 the statement is split in two. `buildDefinition` holds what was asked for: the `buildType`, the `externalParameters` and the `resolvedDependencies`. `runDetails` holds what happened: the `builder` and the `metadata`, such as the start and end time and the `invocationId`.

## Name the builder and the build type

Two keys in `chains-config` fill the fields an auditor checks first:

| Key | Default | What it sets |
| --- | --- | --- |
| `builder.id` | `https://tekton.dev/chains/v2` | The identity of the builder in the statement |
| `builddefinition.buildtype` | Depends on the format | The `buildType` of the v1.0 statements |

Set `builder.id` to a value that names your own installation, such as an URL of your platform team. A verifier can then trust statements by builder, not only by key. Changing it affects only runs Chains handles afterwards.

## Pick by consumer

Choose the format by who reads the statement. A verifier that expects SLSA v1.0, such as a policy engine written against `https://slsa.dev/provenance/v1`, needs a `v2alpha` format. A verifier written against SLSA v0.2 needs `in-toto`. A mix of both works only if the verifier accepts both `predicateType` values. The same `cosign verify-attestation` call needs the matching `--type`: `slsaprovenance` for v0.2 and `slsaprovenance1` for v1.0.

## Common pitfalls

> [!WARNING]
> - **Reading `slsa/v1` as SLSA v1.0.** It writes the v0.2 statement. The v1.0 values are `slsa/v2alpha3` and `slsa/v2alpha4`.
> - **Expecting old runs to change.** Chains handles a run once. Build again to see a new format.
> - **Using the wrong `--type`.** `slsaprovenance` matches v0.2, `slsaprovenance1` matches v1.0.
> - **Treating an `alpha` format as frozen.** Pin the Chains version and read the release notes before an upgrade.
> - **Forgetting the restart after creating the key.** The controller mounts the Secret at start.
