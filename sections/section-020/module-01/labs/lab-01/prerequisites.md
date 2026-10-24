# Prerequisites

Before starting this lab you should be able to:

- Explain the difference between time-based pruning (`ttlSecondsAfterFinished`) and history-based pruning (`successfulHistoryLimit`, `failedHistoryLimit`, `historyLimit`).
- Explain what `enforcedConfigLevel` does in the global Pruner configuration.
- Write a ConfigMap with labels and a multi-line YAML value.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and the standalone **Tekton Pruner v0.4.4**, installed from their release manifests. The Pruner runs in `tekton-pipelines` (`tekton-pruner-controller` and `tekton-pruner-webhook`) with its shipped global configuration: `enforcedConfigLevel: global` and `historyLimit: 100`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- The Task `nightly-check` in `starfleet` and in `outpost`, each with three finished runs. The parameter `outcome` makes a run pass (`pass`) or fail (`fail`).

## Working rules

- Everything is graded on the **final cluster state**, and on what the Pruner does with new runs.
- The grader starts runs of `nightly-check` in both namespaces and waits for the Pruner. Grading takes about five minutes.
- Configure pruning only through the Pruner ConfigMaps. Deleting runs by hand proves nothing.
