# Section 030: Monitor Tekton With Prometheus

A CI/CD system fails in two ways: a build fails, or the system that runs builds slows down or stops. Both are easy to miss when the only signal is a red mark in a Dashboard that nobody watches at night. Metrics turn both into numbers that a monitoring system can store and alert on. Prometheus is the monitoring system most Kubernetes clusters use, and every Tekton controller can serve its metrics in the Prometheus format.

This section connects Tekton to Prometheus. You first read the metrics the Tekton Pipelines controller serves and the ConfigMap that controls them. Then you make Prometheus scrape the controller and query the metrics with PromQL. Last, you write alerting rules that fire when TaskRuns fail, and follow an alert through its states.

**Topic covered:** Monitoring

## What you will learn

- How the Tekton Pipelines controller exports metrics with OpenTelemetry, and the ConfigMap `config-observability` (`metrics-protocol`, levels, duration types).
- The main Tekton metrics: `tekton_pipelines_controller_taskrun_total`, `..._pipelinerun_total`, `..._running_taskruns`, `..._running_pipelineruns` and the duration histograms.
- Reading `/metrics` through the API server's Service proxy.
- A Prometheus scrape job for the controller Service on port `9090`, and how a Prometheus Operator setup does the same with a ServiceMonitor.
- PromQL queries for failure counts, running runs and duration percentiles.
- Alerting rules: `expr`, `for`, `labels`, `annotations`, and the states `inactive`, `pending` and `firing`.
- One scrape job per component, and the metrics port of Chains, the Pruner and the webhook.
- Recording rules, the `level:metric:operations` naming, and reading a recorded series back.
- Alerts on running and slow runs and on missing metrics.
- Metric levels, `metric_relabel_configs` and retention to keep the series count down.

## The learning path

The section has two modules. Each has a landing page, short parts, a graded lab right after the part it tests, a summary and a knowledge check. Each module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Monitor Tekton With Prometheus

The module starts at its landing page, which also launches the playground. The playground runs Tekton Pipelines v1.17.1 and, in the namespace `monitoring`, a small Prometheus server that does not scrape Tekton yet, plus a client pod with `curl` and `jq`.

1. The Metrics Tekton Exposes
2. Scrape Tekton With Prometheus
3. Alert On Failed TaskRuns, followed by the lab **Scrape Tekton And Alert On Failed TaskRuns**
4. Summary

### 2. Query And Tune Tekton Metrics

The second module goes deeper. The playground runs Tekton Pipelines v1.17.1, Chains and the Pruner, and a Prometheus server in `monitoring` that scrapes the Pipelines controller.

1. Scrape The Other Tekton Components
2. Precompute Queries With Recording Rules
3. Alert On Stuck And Slow Runs, followed by the lab **Record Failure Ratio And Alert On Stuck TaskRuns**
4. Keep The Series Count Under Control
5. Summary

## Section capstone: Repair Tekton Monitoring

The capstone is one graded scenario that combines the whole module. Every nightly check of the `starfleet` team failed for three days and no alert fired, although Prometheus has a Tekton scrape job and an alert. Find the fault on the Tekton side, the fault in the scrape job and the fault in the alert, and prove the repair with a failed run that fires the alert. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-129-capstone-030
```
