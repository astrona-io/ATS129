# Overview: Provenance Formats, Storage And Signers (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Tekton Pipelines, Tekton Chains, an image registry and a pod with the signing tools. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1** in `tekton-pipelines` and `tekton-pipelines-resolvers`.
- **Tekton Chains v0.29.9** in `tekton-chains`. Tekton Chains is a controller that watches finished TaskRuns and PipelineRuns, writes provenance (a signed record of how an artifact was built) and signs it. It starts with no signing key and an empty `chains-config`, so its defaults apply:

  | Object | Namespace | What it is |
  | --- | --- | --- |
  | Deployment `tekton-chains-controller` | `tekton-chains` | The Chains controller |
  | Secret `signing-secrets` | `tekton-chains` | Empty. The signing key goes here |
  | ConfigMap `chains-config` | `tekton-chains` | No data. Formats, storage and signers go here |
  | Service `tekton-chains-metrics` | `tekton-chains` | Controller metrics on port `9090` |

- An OCI registry (Distribution `registry:3.1.2`) that every pod reaches as `registry.localtest.me:5001`. It speaks plain HTTP, which is fine only in a lab.
- The workstation pod, `deploy/workstation` in the namespace `workstation`, with **cosign 3.1.4**, **regctl 0.11.7**, `curl` and `jq`. Its ServiceAccount may read and write the Secrets in `tekton-chains`, so `cosign` can use the key reference `k8s://tekton-chains/signing-secrets`.
- The `tkn` command-line tool, version **0.46.2**, and an empty namespace `starfleet`.

## Helpers

Paste these once in each new terminal. `show_chains` prints the Chains annotations of one TaskRun. `show_tags` lists the tags of one repository in the registry. `in_workstation` runs one command in the workstation pod.

```sh
show_chains() {
  kubectl get taskrun "$1" -n starfleet -o yaml | grep 'chains.tekton.dev/'
}
show_tags() {
  kubectl exec -n workstation deploy/workstation -- regctl tag ls "registry.localtest.me:5001/starfleet/$1"
}
in_workstation() {
  kubectl exec -n workstation deploy/workstation -- "$@"
}
```

Use them like this: `show_chains hello-run`, `show_tags bridge`, `in_workstation cosign version`.

## Practice tasks

- Run a TaskRun before you create any key, and read the Chains annotations and the controller log. What does `chains.tekton.dev/signed` say, and was anything signed?
- Create a key pair with `cosign generate-key-pair k8s://tekton-chains/signing-secrets` in the workstation pod, run another TaskRun, and read its `chains.tekton.dev/payload-taskrun-<uid>` annotation with `base64 -d`.
- Switch `artifacts.taskrun.format` between `in-toto` and `slsa/v2alpha4`, build an image each time, and compare the `predicateType` that `cosign verify-attestation` prints.
- Remove `storage.oci.repository.insecure` from `chains-config`, build again, and follow the `chains.tekton.dev/retries` annotation until Chains gives up.
- Set `transparency.enabled` to `manual` and find which annotation a TaskRun needs before Chains uploads it to a transparency log.
