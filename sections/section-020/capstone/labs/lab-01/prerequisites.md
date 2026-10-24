# Prerequisites

Before starting this capstone you should be able to:

- Configure the Tekton Pruner with `tekton-pruner-default-spec` and `tekton-pruner-namespace-spec`.
- Explain `enforcedConfigLevel` and `ttlSecondsAfterFinished`.
- Read why the API server refuses an object, and what a validating admission webhook with `failurePolicy: Fail` does.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and the standalone **Tekton Pruner v0.4.4** in `tekton-pipelines`, in the state the task describes.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- The Task `nightly-check` in `starfleet` and `outpost`, with a few finished runs.

## Working rules

- Everything is graded on the **final cluster state**, and on what the Pruner does with new runs.
- Repair the installation in place; do not reinstall the Pruner and do not change its webhook configuration.
- The grader starts runs in both namespaces and waits for the Pruner. Grading takes about four minutes.
