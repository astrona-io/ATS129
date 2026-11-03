# Prerequisites

Before starting this lab you should be able to:

- Read a `Task` and a `TaskRun`, including `params` and `results`.
- Edit a ConfigMap with `kubectl`.
- Explain what Tekton Chains does after a TaskRun ends, and name the annotations it writes.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Tekton Chains v0.29.9**, installed from their release manifests. Chains has a working cosign key in `signing-secrets`.
- An OCI registry that every pod in the cluster reaches as `registry.localtest.me:5001`. It speaks plain HTTP, which is fine only in a lab.
- The workstation pod (`deploy/workstation` in the namespace `workstation`) with **cosign 3.1.4**, **regctl 0.11.7**, `curl` and `jq`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- The Task `build-image` and the TaskRun `build-bridge` in `starfleet`. `build-bridge` was signed with the default provenance settings.

## Working rules

- Chains handles a finished run once. To see a new setting at work, create the run again.
- Run `cosign` in the workstation pod, as in the readings.
