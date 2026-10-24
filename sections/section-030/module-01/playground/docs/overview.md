# Overview: Monitor Tekton With Prometheus (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Tekton Pipelines and a small Prometheus server that does not know about Tekton yet. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1**. The Service `tekton-pipelines-controller` in `tekton-pipelines` serves the controller metrics on its port `http-metrics` (`9090`); the ConfigMap `config-observability` controls them.
- In the namespace `monitoring`:

  | Object | What it is |
  | --- | --- |
  | Deployment and Service `prometheus` | Prometheus v3.15.1 on port `9090`. It scrapes only itself, every 15 seconds, and evaluates rules every 15 seconds |
  | ConfigMap `prometheus-config` | `prometheus.yml` and an empty `tekton-rules.yml`. Prometheus reads both only when it starts |
  | Deployment `client` | A pod with `curl` and `jq`, for calls to the Prometheus API |

- The `tkn` command-line tool, version **0.46.2**, and an empty namespace `starfleet`.
- The images `busybox:1.37.0`, `prom/prometheus:v3.15.1` and `nicolaka/netshoot:v0.13`, already loaded on the node.

Open the Prometheus web interface in a browser with `kubectl port-forward -n monitoring svc/prometheus 9090:9090` and `http://localhost:9090`.

## Helpers

Paste these once in each new terminal. `promql` runs a PromQL query through the client pod and prints each series with its value. `tekton_metrics` lists the Tekton metric names the controller serves right now.

```sh
promql() {
  kubectl exec -n monitoring deploy/client -- env QUERY="$1" sh -c \
    'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=$QUERY" | jq -c ".data.result[] | [.metric, .value[1]]"'
}
tekton_metrics() {
  kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pipelines-controller:http-metrics/proxy/metrics | grep -o '^tekton_[a-z_]*' | sort -u
}
```

Use them like this: `promql 'up'`, `promql 'sum by (status) (tekton_pipelines_controller_taskrun_total)'`, `tekton_metrics`.

## Practice tasks

- Run `tekton_metrics` before and after the first TaskRun ends. Which metrics appear only after a run has finished?
- Set `metrics.taskrun.level` to `taskrun` in `config-observability`, restart the controller, and compare the labels of `tekton_pipelines_controller_taskrun_duration_seconds_count`.
- Write a PromQL query for the 90th percentile of TaskRun duration per Task with `histogram_quantile` and `..._bucket`.
- Add an alert with `for: 2m` that fires while more than 5 TaskRuns run, start six long runs, and follow the alert from `pending` to `firing`.
- Scrape the Tekton webhook and the events controller too (both Services have an `http-metrics` port) and compare their metrics.
