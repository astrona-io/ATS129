# Prerequisites

Before starting this lab you should be able to:

- Write a Prometheus rule file with a group, a recording rule (`record`, `expr`) and an alerting rule (`alert`, `expr`, `for`, `labels`).
- Name the Tekton metric for finished TaskRuns and the gauge for running TaskRuns.
- Query the Prometheus API with `curl`.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** with its default `config-observability`.
- In `monitoring`: **Prometheus v3.15.1** (`deploy/prometheus`, Service `prometheus` on port `9090`) and a client pod (`deploy/client`) with `curl` and `jq`. Prometheus reads `prometheus.yml` and `tekton-rules.yml` from the ConfigMap `prometheus-config`, only when it starts. It scrapes itself and the Pipelines controller every 15 seconds, and evaluates rules every 15 seconds. `tekton-rules.yml` has no groups yet.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- In `starfleet`: the Task `nightly-check` with one passed and one failed run, and the Task `slow-check`, which sleeps for the number of seconds in its parameter `seconds` (default 240).

## Working rules

- Everything is graded on the **final cluster state**: which rules Prometheus loaded, what the recording rule stores, and whether the alert fires.
- The grader starts three TaskRuns of `slow-check` of its own and waits for the alert.
