# Scrape The Other Tekton Components

The Pipelines controller tells you how runs behave. It does not tell you whether the Chains controller signed them or whether the Pruner deleted old ones. Each Tekton component is a separate Deployment with its own metrics endpoint, and each needs its own scrape job. This part adds them one by one and shows how to find out what each endpoint serves before you write a single query.

## Find the metrics Service of each component

Every Tekton component serves metrics over HTTP on port `9090`, but the Service that exposes the port has a different name in each namespace. List the Services that have a port called `http-metrics` or a name that contains `metrics`:

<!-- astrona:playground:renew -->

```sh
kubectl get services -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" "}{range .spec.ports[*]}{.name}={.port}{" "}{end}{"\n"}{end}' | grep -i metrics
```

The output includes `tekton-pipelines/tekton-pipelines-controller`, `tekton-pipelines/tekton-pipelines-webhook`, `tekton-pipelines/tekton-events-controller`, `tekton-pipelines/tekton-pruner-controller` and `tekton-chains/tekton-chains-metrics`. Each lists a port that serves metrics. The rule is the same as before: use the port that is named for metrics, never the probes or profiling port.

## Read an endpoint before you scrape it

The API server can proxy a request to a named port of a Service. Use it to read the Chains endpoint without any Prometheus:

```sh
kubectl get --raw /api/v1/namespaces/tekton-chains/services/tekton-chains-metrics:9090/proxy/metrics | grep -v '^#' | head -n 20
```

The command prints the first lines of the Prometheus text format. Metric names depend on the version of the component, so list the distinct names before you write a query on them:

```sh
kubectl get --raw /api/v1/namespaces/tekton-chains/services/tekton-chains-metrics:9090/proxy/metrics | grep -o '^[a-zA-Z_:][a-zA-Z0-9_:]*' | sort -u
```

Do the same for the Pruner, whose Service is `tekton-pruner-controller` in `tekton-pipelines`:

```sh
kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pruner-controller:9090/proxy/metrics | grep -o '^[a-zA-Z_:][a-zA-Z0-9_:]*' | sort -u
```

The lists show the names that exist in the installed version. Counters for work a component has not done yet, such as signed runs, appear only after the first event, so an empty list for a fresh component is normal.

## Add one job per component

Prometheus keeps the origin of every series in the label `job`, which is the `job_name` of the scrape job, and in the label `instance`, which is the target address. Give each component its own job so a query and an alert can select it. Save this as `configmap-prometheus-config.yaml`:

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
      - job_name: tekton-chains
        static_configs:
          - targets: ["tekton-chains-metrics.tekton-chains.svc:9090"]
      - job_name: tekton-pruner
        static_configs:
          - targets: ["tekton-pruner-controller.tekton-pipelines.svc:9090"]
  tekton-rules.yml: |
    groups: []
```

Apply it and restart Prometheus, which reads its files only when it starts:

```sh
kubectl apply -f configmap-prometheus-config.yaml
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout status deployment/prometheus -n monitoring
```

Then check every target, after the first scrape (up to 15 seconds):

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/targets | jq -r ".data.activeTargets[] | .labels.job + \" \" + .health + \" \" + .scrapeUrl"'
```

Each job reports `up` with a `scrapeUrl` that ends in `/metrics`. A job whose health is `down` shows the reason in the field `lastError`, which the same API returns. A wrong port or Service name there gives a connection error or a DNS error, so the error text tells you which part you got wrong.

## Select a component in a query

With one job per component, a query picks a component by label. The query `up` returns one series per job, and the next query counts the series each job stores:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=count by (job) ({job!=\"\"})" | jq -c ".data.result[] | [.metric.job, .value[1]]"'
```

The selector `{job!=""}` matches every series that has a job label. The result lists the number of series for each job, which is the first look at the cost of each component. The final part of this module returns to that number.

In a cluster with the Prometheus Operator, the same setup uses one `ServiceMonitor` per component instead of a static target. The Service labels and the port name decide what it selects, so the findings above (the Service names and the metrics port names) are the facts you need there too.

You can now find the metrics endpoint of each Tekton component, read it directly, scrape it under its own job, and select it in a query. Every query so far still runs over raw series each time you ask. The open question is how to make a heavy query cheap enough to run on a dashboard.

## Common pitfalls

> [!WARNING]
> - **One job for several components.** The `job` label then no longer tells you which component a series came from.
> - **A Service name from memory.** Component Services differ in name and namespace; list them before you write targets.
> - **Waiting for a Chains counter on a fresh cluster.** Counters appear after the first event, so an empty list is not a fault.
> - **Forgetting the restart.** This Prometheus reads `prometheus.yml` only at start.
> - **Using the profiling port.** Port `8008` serves profiling data, not metrics.
