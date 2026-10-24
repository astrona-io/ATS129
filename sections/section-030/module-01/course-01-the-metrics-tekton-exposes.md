# The Metrics Tekton Exposes

Before you can alert on anything, you need to know which numbers exist, where they are served, and what their labels mean. A metric with the wrong label value, or a port that serves something else, is the most common reason why an alert stays silent. This part opens the metrics endpoint of the Tekton Pipelines controller and reads it directly, without any monitoring system in between.

## Where the metrics are served

Every Tekton Pipelines component serves its metrics over HTTP on port `9090`, and its Service names that port `http-metrics`. Look at the ports of the controller Service:

<!-- astrona:playground:renew -->

```sh
kubectl get service tekton-pipelines-controller -n tekton-pipelines -o jsonpath='{range .spec.ports[*]}{.name}={.port}{"\n"}{end}'
```

It lists `http-metrics=9090`, `http-profiling=8008` and `probes=8080`. Only the first one serves metrics. You can read it without a port-forward through the API server's Service proxy, which forwards a request to a named port of a Service:

```sh
kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pipelines-controller:http-metrics/proxy/metrics | grep '^tekton_pipelines_controller_' | sort -u -t '{' -k1,1
```

The output is the Prometheus text format: one line per time series, a metric name, labels in braces, and a value. Right after a start you see the gauges, such as `tekton_pipelines_controller_running_taskruns` and `tekton_pipelines_controller_running_pipelineruns`. A gauge is a value that goes up and down. The counters and histograms of finished runs appear only after the first run has finished.

## What controls them: config-observability

Since Tekton Pipelines 1.x, the controller exports metrics with OpenTelemetry, a standard for telemetry data, and the ConfigMap `config-observability` in `tekton-pipelines` decides how:

```sh
kubectl get configmap config-observability -n tekton-pipelines -o jsonpath='{.data.metrics-protocol}{"\n"}'
```

It prints `prometheus`. The key `metrics-protocol` has four values:

| Value | Effect |
| --- | --- |
| `prometheus` | Serve `/metrics` over HTTP on port `9090` (set in the release) |
| `grpc` | Push to an OpenTelemetry Collector over OTLP gRPC at `metrics-endpoint` |
| `http/protobuf` | Push to an OpenTelemetry Collector over OTLP HTTP at `metrics-endpoint` |
| `none` | Export no metrics |

The same ConfigMap sets how detailed the run metrics are. The level keys decide which labels a series gets, and each extra label multiplies the number of series that Prometheus must store:

| Key | Default | Other values |
| --- | --- | --- |
| `metrics.taskrun.level` | `task` (label `task`, no `taskrun`) | `taskrun` adds the run name; `namespace` drops `task` too |
| `metrics.pipelinerun.level` | `pipeline` | `pipelinerun`, `namespace` |
| `metrics.taskrun.duration-type` | `histogram` | `lastvalue` (a gauge) |
| `metrics.count.enable-reason` | `"false"` | `"true"` adds the label `reason` to the duration metrics |

Keep the run name out of metrics in a real cluster: `taskrun` and `pipelinerun` levels create a new series for every run, which Prometheus cannot store for long. The controller reads these keys when it starts, so restart `tekton-pipelines-controller` after a change.

## Watch a counter move

Run one Task that succeeds and one that fails, then read the counters. Save this as `task-nightly-check.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: nightly-check
  namespace: starfleet
spec:
  params:
    - name: outcome
      type: string
      default: pass
  steps:
    - name: check
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        echo "nightly check: $(params.outcome)"
        [ "$(params.outcome)" = "pass" ]
```

Apply it and start two runs:

```sh
kubectl apply -f task-nightly-check.yaml
tkn task start nightly-check -n starfleet -p outcome=pass --showlog
tkn task start nightly-check -n starfleet -p outcome=fail --showlog
```

Then check the result:

```sh
kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pipelines-controller:http-metrics/proxy/metrics | grep -E '^tekton_pipelines_controller_taskrun_(total|duration_seconds_count)'
```

`tekton_pipelines_controller_taskrun_total` now has two series, one with `status="success"` and one with `status="failed"`, each with the value `1`. A counter only goes up; it starts again at zero when the controller restarts. `tekton_pipelines_controller_taskrun_duration_seconds_count` has a series per `task`, `namespace` and `status`, the count part of the duration histogram. The controller writes three status values: `success`, `failed` and `cancelled`.

These are the metrics of the controller that matter most:

| Metric | Type | Labels |
| --- | --- | --- |
| `tekton_pipelines_controller_taskrun_total` | Counter | `status` |
| `tekton_pipelines_controller_pipelinerun_total` | Counter | `status` |
| `tekton_pipelines_controller_taskrun_duration_seconds` | Histogram | `namespace`, `status`, `task` (by level) |
| `tekton_pipelines_controller_pipelinerun_duration_seconds` | Histogram | `namespace`, `status`, `pipeline` (by level) |
| `tekton_pipelines_controller_running_taskruns` | Gauge | none |
| `tekton_pipelines_controller_running_pipelineruns` | Gauge | none |
| `tekton_pipelines_controller_running_taskruns_throttled_by_quota` | Gauge | `namespace` (optional) |

Every series also carries the label `otel_scope_name`, which names the code that recorded it. Other Tekton projects serve their own metrics the same way: the Chains controller on the Service `tekton-chains-metrics` and the Pruner controller on the Service `tekton-pruner-controller`, both on port `9090`.

You can now find the metrics endpoint, read it directly, and explain what `config-observability` changes. Reading the endpoint by hand shows only the current values. The open question is how to store them over time and query them.

## Common pitfalls

> [!WARNING]
> - **The wrong port.** `8080` is the `probes` port and `8008` the profiling port. Metrics are on `http-metrics`, port `9090`.
> - **Expecting counters before the first run.** Counters and histograms of finished runs appear only after a run has finished.
> - **A wrong status value.** The controller writes `success`, `failed` and `cancelled`, never `failure` or `Failed`.
> - **`metrics.taskrun.level: taskrun` in production.** It creates one series per run and fills the monitoring storage.
> - **Changing `config-observability` without a restart.** Restart the controller so it applies the new export settings.
