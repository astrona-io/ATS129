# Provenance For PipelineRuns And Images

A real build is a PipelineRun that runs several TaskRuns. Chains signs each TaskRun by itself, and it also writes provenance for the PipelineRun as a whole. The same three settings, format, storage and signer, exist for the PipelineRun and for the images, under their own prefixes. This part uses a two-task Pipeline to show what each prefix controls.

## The three prefixes

| Prefix | Artifact | Default format | Default storage |
| --- | --- | --- | --- |
| `artifacts.taskrun.` | A finished TaskRun | `in-toto` | `tekton` |
| `artifacts.pipelinerun.` | A finished PipelineRun | `in-toto` | `tekton` |
| `artifacts.oci.` | An image a run built | `simplesigning` | `oci` |

Each prefix takes the keys `format`, `storage` and `signer`. A setting for one prefix never changes another. A cluster that sets only `artifacts.taskrun.format` still writes PipelineRun provenance in `in-toto`, and that is the usual cause of two formats in one cluster.

## A Pipeline with two tasks

Create a Pipeline in which a build Task passes its image to a second Task that only prints it:

<!-- astrona:playground:renew -->

```sh
cat <<'YAML' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: build-and-report
  namespace: starfleet
spec:
  params:
    - name: image
  results:
    - name: IMAGE_URL
      value: $(tasks.build.results.IMAGE_URL)
    - name: IMAGE_DIGEST
      value: $(tasks.build.results.IMAGE_DIGEST)
  tasks:
    - name: build
      taskRef:
        name: build-image
      params:
        - name: image
          value: $(params.image)
    - name: report
      runAfter: [build]
      params:
        - name: url
          value: $(tasks.build.results.IMAGE_URL)
      taskSpec:
        params:
          - name: url
        steps:
          - name: print
            image: busybox:1.37.0
            script: |
              echo "built $(params.url)"
YAML
```

The Pipeline results `IMAGE_URL` and `IMAGE_DIGEST` copy the values of the build task. They are what tells Chains which image the PipelineRun produced.

## Configure the PipelineRun settings

Set the format and the storage for PipelineRuns, next to the TaskRun settings:

```sh
kubectl patch configmap chains-config -n tekton-chains --type merge -p '{"data":{"artifacts.pipelinerun.format":"slsa/v2alpha4","artifacts.pipelinerun.storage":"tekton,oci"}}'
tkn pipeline start build-and-report -n starfleet --param image=registry.localtest.me:5001/starfleet/fleet --showlog
```

Wait until Chains has handled the runs, then read the annotations of the PipelineRun. The names end in `pipelinerun-<uid>`:

```sh
PR="$(kubectl get pipelinerun -n starfleet -o jsonpath='{.items[-1].metadata.name}')"
kubectl get pipelinerun "$PR" -n starfleet -o yaml | grep -o 'chains.tekton.dev/[a-z0-9-]*'
```

Each of the two TaskRuns has its own `payload-taskrun-<uid>` and `signature-taskrun-<uid>` annotation too. Three signed statements exist for one execution: one per TaskRun and one for the PipelineRun.

## What the PipelineRun statement lists

The statement of the PipelineRun lists its parameters, the Pipeline definition it ran, and the child TaskRuns. It does not list the images that the child TaskRuns built unless the PipelineRun reports them as results, which is why the Pipeline above copies the results. The image in the registry gets one attestation for each artifact type that names it, so the same image can carry the statement of the TaskRun and the statement of the PipelineRun. A verifier that wants the build of the whole pipeline looks at the second one.

## Deep inspection

A Pipeline whose tasks produce images but whose own results stay empty gives Chains nothing to attach at the PipelineRun level. The key `artifacts.pipelinerun.enable-deep-inspection` changes that. Its default is `"false"`. When it is `"true"`, Chains looks at the results of the child TaskRuns for artifacts and includes them in the PipelineRun provenance:

```sh
kubectl patch configmap chains-config -n tekton-chains --type merge -p '{"data":{"artifacts.pipelinerun.enable-deep-inspection":"true"}}'
```

Turn it on when you cannot change the Pipelines to copy their results. Turn it off when the Pipelines already report results, because deep inspection reads more objects and makes Chains slower on large PipelineRuns.

## The images have their own signer

The image signature is the third artifact type. `artifacts.oci.format` is `simplesigning`, the cosign signature format, and `artifacts.oci.signer` is `x509`. You rarely change the format. You do change the storage when a team wants images signed but not stored in the same registry as the image, which is a reason to use `storage.oci.repository`.

## Verify the layers

Check the image against the key. Both a signature and an attestation exist, and each is verified separately:

```sh
kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data.cosign\.pub}' | base64 -d | kubectl exec -i -n workstation deploy/workstation -- sh -c 'cat > /tmp/cosign.pub'
DIGEST="$(kubectl get pipelinerun "$PR" -n starfleet -o jsonpath='{.status.results[?(@.name=="IMAGE_DIGEST")].value}')"
kubectl exec -n workstation deploy/workstation -- cosign verify --key /tmp/cosign.pub --insecure-ignore-tlog --allow-http-registry "registry.localtest.me:5001/starfleet/fleet@${DIGEST}"
kubectl exec -n workstation deploy/workstation -- cosign verify-attestation --key /tmp/cosign.pub --insecure-ignore-tlog --allow-http-registry --type slsaprovenance1 "registry.localtest.me:5001/starfleet/fleet@${DIGEST}"
```

The first command checks the image signature. The second checks the attestation and exits with `0` when at least one attestation of the type matches. Because both TaskRun and PipelineRun statements are `slsaprovenance1` here, one passing check does not tell you which statement it was. Decode the payloads when you need to know.

## Common pitfalls

> [!WARNING]
> - **Setting only the TaskRun keys.** PipelineRun provenance keeps its own defaults.
> - **A Pipeline without results.** Chains cannot tell which image the PipelineRun built. Copy the results or turn on deep inspection.
> - **Enabling deep inspection everywhere.** It is slower on large PipelineRuns.
> - **Confusing which statement passed.** Both artifact types can use the same `--type`; decode to be sure.
> - **Forgetting `cosign.pub` in the workstation.** The commands above write it to `/tmp/cosign.pub` first.
