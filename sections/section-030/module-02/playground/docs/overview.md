# Overview: Query And Tune Tekton Metrics (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with three Tekton components and a small Prometheus server that already scrapes the Pipelines controller. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1** in `tekton-pipelines`. The Service `tekton-pipelines-controller` serves metrics on its port `http-metrics` (`9090`); the ConfigMap `config-observability` controls them.
- **Tekton Chains v0.29.9** in `tekton-chains`, without a signing key. Its Service `tekton-chains-metrics` serves metrics on port `9090`.
- **The Tekton Pruner v0.4.4** in `tekton-pipelines`. Its Service `tekton-pruner-controller` serves metrics on port `9090`.
- In the namespace `monitoring`:

  | Object | What it is |
  | --- | --- |
  | Deployment and Service `prometheus` | Prometheus v3.15.1 on port `9090`. It scrapes itself and the job `tekton-pipelines-controller` every 15 seconds, and evaluates rules every 15 seconds |
  | ConfigMap `prometheus-config` | `prometheus.yml` and an empty `tekton-rules.yml`. Prometheus reads both only when it starts |
  | Deployment `client` | A pod with `curl` and `jq`, for calls to the Prometheus API |

- The `tkn` command-line tool, version **0.46.2**, and an empty namespace `starfleet`.
- The images `busybox:1.37.0`, `prom/prometheus:v3.15.1` and `nicolaka/netshoot:v0.13`, already loaded on the node.

Open the Prometheus web interface in a browser with `kubectl port-forward -n monitoring svc/prometheus 9090:9090` and `http://localhost:9090`.

## Helpers

Paste these once in each new terminal. `promql` runs a PromQL query through the client pod and prints each series with its value. `prom_api` reads any Prometheus API path.

```sh
promql() {
  kubectl exec -n monitoring deploy/client -- env QUERY="$1" sh -c \
    'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=$QUERY" | jq -c ".data.result[] | [.metric, .value[1]]"'
}
prom_api() {
  kubectl exec -n monitoring deploy/client -- env API_PATH="$1" sh -c \
    'curl -s "http://prometheus.monitoring:9090$API_PATH" | jq .'
}
```

Use them like this: `promql 'up'`, `promql 'count by (job) ({job!=""})'`, `prom_api /api/v1/rules`.

## Practice tasks

- Add scrape jobs for the Chains and the Pruner Services, restart Prometheus, and check that `up` is `1` for both.
- Write a recording rule that stores the share of failed TaskRuns, and read it back with `promql`.
- Start four long TaskRuns at once and write an alert on `tekton_pipelines_controller_running_taskruns`.
- Count the series per metric name with `topk(10, count by (__name__) ({job="tekton-pipelines-controller"}))`, set `metrics.taskrun.level` to `taskrun`, restart the controller, run three TaskRuns and count again.
- Add a `metric_relabel_configs` rule that drops one metric, and confirm that its series stop.
