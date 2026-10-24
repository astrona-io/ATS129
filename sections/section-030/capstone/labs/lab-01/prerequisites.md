# Prerequisites

Before starting this capstone you should be able to:

- Explain how the Tekton Pipelines controller exports metrics and what `config-observability` controls.
- Read the target list and the rules of Prometheus through its API.
- Write a PromQL selector with a label matcher.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1**, in the state the task describes.
- In `monitoring`: **Prometheus v3.15.1** (`deploy/prometheus`, Service `prometheus` on port `9090`) with the ConfigMap `prometheus-config`, which Prometheus reads only when it starts, and a client pod (`deploy/client`) with `curl` and `jq`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- The Task `nightly-check` in `starfleet`. The parameter `outcome` set to `fail` makes a run fail.

## Working rules

- Everything is graded on the **final cluster state**.
- The grader runs a failing TaskRun of its own and waits for the alert.
