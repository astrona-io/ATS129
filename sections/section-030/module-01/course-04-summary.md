# Summary

Monitoring Tekton takes three working pieces: a controller that serves metrics, a Prometheus that scrapes and stores them, and rules that turn them into alerts. When an alert stays silent, one of the three is broken.

## What you learned

The Tekton Pipelines controller exports its metrics with OpenTelemetry. The ConfigMap `config-observability` in `tekton-pipelines` decides how: `metrics-protocol: prometheus` serves `/metrics` on port `9090`, which the controller Service names `http-metrics`, while `grpc` and `http/protobuf` push to an OpenTelemetry Collector and `none` exports nothing. The same ConfigMap sets the level of detail, and the levels `taskrun` and `pipelinerun` create a series for every run, which is too many for a real cluster. The controller applies changes when it restarts.

The main metrics are the counters `tekton_pipelines_controller_taskrun_total` and `..._pipelinerun_total` with the label `status` (`success`, `failed`, `cancelled`), the duration histograms `..._taskrun_duration_seconds` and `..._pipelinerun_duration_seconds`, and the gauges `..._running_taskruns` and `..._running_pipelineruns`. Counters and histograms appear after the first finished run, and counters start again at zero when the controller restarts.

Prometheus pulls metrics from the targets in its scrape jobs and records `up` for each one. A static target with the Service DNS name is the simplest setup; Kubernetes service discovery and the Prometheus Operator's `ServiceMonitor` do the same at scale. PromQL turns the series into answers with `sum by`, `rate`, `increase` and `histogram_quantile`. Alerting rules are PromQL expressions with a name, an optional `for` time, labels and annotations; an alert moves from `inactive` through `pending` to `firing`, and Alertmanager sends it on. The key facts to remember are these:

- Metrics are on the port `http-metrics` (`9090`) of each Tekton Service, never on `probes`.
- `metrics-protocol: none` silences the controller; restart it after changing `config-observability`.
- This Prometheus reads its files only at start: restart it after a change, and name every rule file in `rule_files`.
- Test every alert with a real failure; a selector that matches nothing keeps an alert `inactive` forever.

<!-- astrona:playground:destroy -->
