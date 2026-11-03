# Query And Tune Tekton Metrics

A first alert on failed TaskRuns is only the start. A real installation has more than one Tekton component to watch, dashboards that run the same heavy query every few seconds, alerts for runs that pile up, and a monitoring server whose disk grows with every label value that Tekton adds. This module takes a working Prometheus setup and makes it cheaper to run and more useful to read.

Keep one sentence in mind: **every series costs storage and every query costs time, so decide which series you keep and which answers you precompute.** Prometheus stores one time series for each unique combination of a metric name and its label values. A label with many values, such as a run name, multiplies the series count. The controller's own settings, the scrape job and the rule files are the three places where you control that cost.

The module has four parts. **Scrape The Other Tekton Components** adds the Chains controller, the Pruner and the webhook as targets and shows how to find their metrics. **Precompute Queries With Recording Rules** stores the answer of an expensive query as a new series. **Alert On Stuck And Slow Runs** writes alerts on the running-runs gauge and on duration percentiles. A graded lab follows that part. **Keep The Series Count Under Control** measures cardinality and removes series that nobody uses.

## Learning objectives

After this module you can:

- Add scrape jobs for the Chains controller, the Pruner and the Pipelines webhook, and tell them apart by the `job` label.
- Find out which metrics a Tekton component serves, without a monitoring system.
- Write a recording rule with a name in the `level:metric:operations` form, and read the recorded series.
- Write alerts on `tekton_pipelines_controller_running_taskruns` and on a `histogram_quantile` of run durations, with a `for` time.
- Count series per metric and per job, and explain why the levels `taskrun` and `pipelinerun` grow the count with every run.
- Drop unwanted series at scrape time with `metric_relabel_configs`.

## Before you start

You need to know how Prometheus scrapes a target, what a PromQL `rate` does, and what an alerting rule is. In short: Prometheus pulls metrics from a target over HTTP at a fixed interval, `rate` turns a counter into a per-second change over a time window, and an alerting rule is a PromQL expression that Prometheus checks at every evaluation.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 and the Tekton Pruner v0.4.4 |
| Namespace `tekton-chains` | Tekton Chains v0.29.9, without a signing key |
| `deploy/prometheus` in `monitoring` | Prometheus v3.15.1, scraping itself and the Pipelines controller, configured by the ConfigMap `prometheus-config` |
| `deploy/client` in `monitoring` | A pod with `curl` and `jq` for calls to the Prometheus API |
| Namespace `starfleet` | Empty. Your Tasks and TaskRuns go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
