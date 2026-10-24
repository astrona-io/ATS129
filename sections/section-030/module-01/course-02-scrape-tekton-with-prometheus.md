# Scrape Tekton With Prometheus

The metrics endpoint shows only the values of this moment. To see that failures started at three in the morning, or that runs take twice as long as last week, something must read the endpoint every few seconds and keep the history. That is what Prometheus does. This part adds the Tekton controller to the playground's Prometheus and queries the metrics with PromQL.

## How Prometheus finds a target

Prometheus pulls metrics. Its configuration file lists scrape jobs; each job names targets, and every `scrape_interval` Prometheus sends `GET /metrics` to each target and stores the result. For every target it also records the series `up`: `1` if the last scrape worked, `0` if not.

The playground's Prometheus reads `prometheus.yml` and `tekton-rules.yml` from the ConfigMap `prometheus-config`. Read the current file:

<!-- astrona:playground:renew -->

```sh
kubectl get configmap prometheus-config -n monitoring -o jsonpath='{.data.prometheus\.yml}'
```

It has one job, `prometheus`, which scrapes Prometheus itself on `localhost:9090`, and it loads rules from `/etc/prometheus/tekton-rules.yml`. Scrape and rule evaluation both run every 15 seconds.

There are three common ways to point Prometheus at the Tekton controller. A static target names the Service by its DNS name, `tekton-pipelines-controller.tekton-pipelines.svc:9090`; that is what this part uses, because it needs no extra permissions. Kubernetes service discovery (`kubernetes_sd_configs`) lets Prometheus list Services or endpoints through the API server and keep only those that match, which needs RBAC permissions for Prometheus. In a cluster with the Prometheus Operator, a `ServiceMonitor` resource selects the Service by label and names the port `http-metrics`, and the Operator writes the scrape job for you.

## Add the Tekton scrape job

Save this as `configmap-prometheus-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    rule_files:
      - /etc/prometheus/tekton-rules.yml
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ["localhost:9090"]
      - job_name: tekton-pipelines-controller
        static_configs:
          - targets: ["tekton-pipelines-controller.tekton-pipelines.svc:9090"]
  tekton-rules.yml: |
    groups: []
```

Apply it. Prometheus reads its files only when it starts, so restart it:

```sh
kubectl apply -f configmap-prometheus-config.yaml
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout status deployment/prometheus -n monitoring
```

Then check the targets through the Prometheus API, from the client pod:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/targets | jq -r ".data.activeTargets[] | .labels.job + \" \" + .scrapeUrl + \" \" + .health"'
```

After the first scrape, both jobs show `up`, and the Tekton job scrapes `http://tekton-pipelines-controller.tekton-pipelines.svc:9090/metrics`. If a target shows `down`, the same API returns its `lastError`, which usually names a refused connection or a wrong path.

## Query the metrics with PromQL

PromQL selects series by metric name and labels, and adds functions and aggregations on top. Run a few queries through the client pod. The first counts finished TaskRuns by status; the second shows how many run right now:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=sum by (status) (tekton_pipelines_controller_taskrun_total)" | jq -c ".data.result[] | [.metric.status, .value[1]]"'
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=tekton_pipelines_controller_running_taskruns" | jq -c ".data.result[] | .value[1]"'
```

The first prints one line per status that has occurred since the controller started, such as `["failed","1"]` and `["success","1"]` after one run of each. The second prints `0` while nothing runs. These are the queries you will use most; you can also run them in the web interface after `kubectl port-forward -n monitoring svc/prometheus 9090:9090`:

| Question | PromQL |
| --- | --- |
| Failed TaskRuns in the last hour | `sum(increase(tekton_pipelines_controller_taskrun_total{status="failed"}[1h]))` |
| Share of failed TaskRuns over 30 minutes | `sum(rate(tekton_pipelines_controller_taskrun_total{status="failed"}[30m])) / sum(rate(tekton_pipelines_controller_taskrun_total[30m]))` |
| TaskRuns running now | `tekton_pipelines_controller_running_taskruns` |
| 90th percentile of TaskRun duration per Task | `histogram_quantile(0.9, sum by (le, task) (rate(tekton_pipelines_controller_taskrun_duration_seconds_bucket[1h])))` |
| Is the controller scraped? | `up{job="tekton-pipelines-controller"}` |

A counter starts again at zero when the controller restarts, so use `rate` or `increase` over a time window instead of the raw value for trends. Both functions handle that reset.

You can now make Prometheus scrape the controller, check the target, and answer questions about failures, load and duration with PromQL. Nobody reads queries at three in the morning, though. The open question is how to make Prometheus raise an alert by itself.

## Common pitfalls

> [!WARNING]
> - **Forgetting the restart.** This Prometheus reads its files only at start. A changed ConfigMap does nothing until the pod restarts.
> - **Scraping a pod IP address.** It changes with every restart of the controller. Use the Service name or service discovery.
> - **Reading raw counter values as trends.** Counters reset when the controller restarts. Use `rate` or `increase`.
> - **A `job` name that does not match your queries.** The `job` label comes from `job_name`; queries and alerts that filter on it must use the same name.
> - **Expecting series before they exist.** The counter for `status="failed"` appears only after the first failed run.
