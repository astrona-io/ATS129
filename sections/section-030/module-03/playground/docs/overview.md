# Overview: Route Alerts With Alertmanager And The Prometheus Operator (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Tekton Pipelines, a small Prometheus server that scrapes the Pipelines controller and has two alerts, and an Alertmanager that has no routes yet. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1** in `tekton-pipelines`. The Service `tekton-pipelines-controller` serves metrics on its port `http-metrics` (`9090`); the ConfigMap `config-observability` controls them.
- **Tekton Chains v0.29.9** in `tekton-chains`, without a signing key. Its Service `tekton-chains-metrics` serves metrics on port `9090`.
- **The Tekton Pruner v0.4.4** in `tekton-pipelines`. Its Service `tekton-pruner-controller` serves metrics on port `9090`.
- In the namespace `monitoring`:

  | Object | What it is |
  | --- | --- |
  | Deployment and Service `prometheus` | Prometheus v3.15.1 on port `9090`. It scrapes itself and the job `tekton-pipelines-controller` every 15 seconds, and evaluates rules every 15 seconds |
  | ConfigMap `prometheus-config` | `prometheus.yml`, which sends alerts to `alertmanager.monitoring.svc:9093`, and `tekton-rules.yml` with the alerts `TektonTooManyRunningTaskRuns` (warning) and `TektonControllerDown` (critical). Prometheus reads both only when it starts |
  | Deployment and Service `alertmanager` | Alertmanager v0.28.1 on port `9093`. Its config comes from the ConfigMap `alertmanager-config`: one receiver `team-default` and no child routes |
  | Deployment `client` | A pod with `curl` and `jq`, for calls to the Prometheus API |

- The `tkn` command-line tool, version **0.46.2**, and an empty namespace `starfleet`.
- The images `busybox:1.37.0`, `prom/prometheus:v3.15.1`, `quay.io/prometheus/alertmanager:v0.28.1` and `nicolaka/netshoot:v0.13`, already loaded on the node.

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

Use them like this: `promql 'up'`, `prom_api /api/v1/rules`, `prom_api /api/v1/alerts`.

## Practice tasks

- Read `/api/v2/status` of Alertmanager from the client pod and find the config it loaded.
- Run `amtool check-config` and `amtool config routes` in the alertmanager pod against its own config file.
- Add a child route for `severity=critical` with its own receiver, restart Alertmanager, and test it with `amtool config routes test`.
- Create a silence with `amtool silence add` for `alertname=TektonControllerDown` and list it with `amtool silence query`.
- Scale `tekton-pipelines-controller` to zero and follow `TektonControllerDown` from `inactive` to `pending` to `firing` in `/api/v1/alerts`, then find the alert in Alertmanager at `/api/v2/alerts`.
