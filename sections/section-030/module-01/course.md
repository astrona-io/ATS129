# Monitor Tekton With Prometheus

At three in the morning a base image disappears from a registry, and every build fails from then on. Nobody notices until the first person opens the Dashboard. Or the Tekton controller runs out of memory, restarts again and again, and runs queue up. Both problems show up in numbers long before anyone complains, if something collects the numbers and raises an alert.

The Tekton Pipelines controller counts every TaskRun and PipelineRun it finishes, measures how long they took, and reports how many are running. It serves these numbers as metrics on port `9090` in the Prometheus text format. Prometheus is a monitoring system that scrapes such endpoints at a fixed interval, stores the values as time series, answers queries in its language PromQL, and evaluates alerting rules.

Keep one sentence in mind: **Tekton serves the numbers, Prometheus pulls them and decides when to alert.** If an alert does not fire, the fault is in one of three places: the controller does not serve metrics, Prometheus does not scrape them, or the rule does not match them.

The module has three parts. **The Metrics Tekton Exposes** reads the controller's metrics endpoint and the ConfigMap that controls it. **Scrape Tekton With Prometheus** adds a scrape job and queries the metrics with PromQL. **Alert On Failed TaskRuns** writes alerting rules and follows an alert from `inactive` to `firing`. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Find the metrics port of the Tekton Pipelines controller and read its metrics through the API server.
- Explain the keys of `config-observability`: `metrics-protocol`, `metrics.taskrun.level`, `metrics.pipelinerun.level` and the duration types.
- Name the main Tekton metrics and their labels.
- Add a Prometheus scrape job for the Tekton controller and check that the target is up.
- Query failures, running runs and durations with PromQL.
- Write an alerting rule, load it, and read its state through the Prometheus API.

## Before you start

You need Kubernetes basics and Tekton basics: a `TaskRun` is one execution of a `Task`, and its `Succeeded` condition ends as `True` or `False`. You should know what a Service and a port name are. You do not need to know Prometheus yet.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1, with its default `config-observability` |
| `deploy/prometheus` in `monitoring` | Prometheus v3.15.1, scraping only itself, configured by the ConfigMap `prometheus-config` |
| `deploy/client` in `monitoring` | A pod with `curl` and `jq` for calls to the Prometheus API |
| Namespace `starfleet` | Empty. Your Tasks and TaskRuns go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
