# Prerequisites

Before starting this capstone you should be able to:

- Configure Tekton Chains in `chains-config` and give it a cosign key in `signing-secrets`.
- Read the log of the Chains controller and the annotations it writes on a TaskRun.
- Verify an image signature and an attestation with `cosign verify` and `cosign verify-attestation`.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and **Tekton Chains v0.29.9**, in the state the task describes.
- An OCI registry that every pod in the cluster reaches as `registry.localtest.me:5001` over plain HTTP (lab-only).
- The workstation pod (`deploy/workstation` in `workstation`) with **cosign 3.1.4**, **regctl 0.11.7**, `curl` and `jq`. Its ServiceAccount may read and write the Secrets in `tekton-chains`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- In `starfleet`: the Task `release-image`, the TaskRun `release-shuttle`, the Secret `release-key-escrow` and the ConfigMap `release-key`.

## Working rules

- Everything is graded on the **final cluster state**.
- Keep the release key pair. The grader verifies with the release public key it recorded when the capstone started.
- The grader starts a release of its own, so every new run of `release-image` must be signed.
