# Prerequisites

Before starting this lab you should be able to:

- Read an Alertmanager configuration: the `route` tree, `matchers`, `group_by`, `group_wait`, `repeat_interval` and `receivers`.
- Use `amtool config routes test` to see which receiver a set of labels reaches.
- Restart a Deployment with `kubectl rollout restart` and wait for it.

## What the environment gives you

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** with its default `config-observability`.
- In `monitoring`: **Prometheus v3.15.1** (Service `prometheus`, port `9090`) with two alert rules, **Alertmanager v0.28.1** (`deploy/alertmanager`, Service `alertmanager`, port `9093`) and a client pod (`deploy/client`) with `curl` and `jq`. Prometheus sends its alerts to Alertmanager. Alertmanager reads `alertmanager.yml` from the ConfigMap `alertmanager-config` only when it starts.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- In `starfleet`: the Task `slow-check`, which sleeps for the number of seconds in its parameter `seconds` (default 240).

## Working rules

- Everything is graded on the **final cluster state**: the routes Alertmanager has loaded and where a live alert is delivered.
- The grader starts three TaskRuns of `slow-check` of its own to raise the warning alert.
