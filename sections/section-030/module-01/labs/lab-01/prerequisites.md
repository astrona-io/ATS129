# Prerequisites

Before starting this lab you should be able to:

- Name the metrics port of the Tekton Pipelines controller and a few of its metrics.
- Write a Prometheus scrape job with `static_configs` and an alerting rule with `expr` and `labels`.
- Query the Prometheus API with `curl`.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** with its default `config-observability` (`metrics-protocol: prometheus`).
- In `monitoring`: **Prometheus v3.15.1** (`deploy/prometheus`, Service `prometheus` on port `9090`) and a client pod (`deploy/client`) with `curl` and `jq`. Prometheus reads `prometheus.yml` and `tekton-rules.yml` from the ConfigMap `prometheus-config`, only when it starts. It scrapes only itself, every 15 seconds, and evaluates rules every 15 seconds.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- The Task `nightly-check` in `starfleet` with one successful run. The parameter `outcome` set to `fail` makes a run fail.

## Working rules

- Everything is graded on the **final cluster state**: what Prometheus scrapes, which rules it loaded, and whether the alert fires.
- The grader runs a failing TaskRun of its own and waits for the alert.
