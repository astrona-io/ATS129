# Prerequisites

Before starting this lab you should be able to:

- Read a `Task` and a `TaskRun`, including `params` and `results`.
- Edit a ConfigMap and a Secret with `kubectl`.
- Explain what Tekton Chains does after a TaskRun ends, and what the results `IMAGE_URL` and `IMAGE_DIGEST` tell it.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Tekton Chains v0.29.9**, installed from their release manifests. Chains has no signing key yet, and `chains-config` has no data, so the defaults apply.
- An OCI registry that every pod in the cluster reaches as `registry.localtest.me:5001`. It speaks plain HTTP, which is fine only in a lab.
- The workstation pod (`deploy/workstation` in the namespace `workstation`) with **cosign 3.1.4**, **regctl 0.11.7**, `curl` and `jq`. Its ServiceAccount may read and write the Secrets in `tekton-chains`, so `cosign` can use `k8s://tekton-chains/signing-secrets`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- The Task `build-image` and the TaskRun `build-bridge` in `starfleet`.

## Working rules

- Everything is graded on the **final cluster state**.
- The grader reads the public key from `signing-secrets` and runs `cosign verify` and `cosign verify-attestation` in the workstation pod.
- The grader starts a build of its own, so every new run of `build-image` must be signed, not only `build-bridge`.
