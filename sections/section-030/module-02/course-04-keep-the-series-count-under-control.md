# Keep The Series Count Under Control

Prometheus keeps every sample of every series in memory for a while and on disk for the retention time. Memory use and disk use grow with the number of series, not with the number of metrics. A metric with one label that has a thousand values is a thousand series. This property, called cardinality, is the main reason why a monitoring server runs out of memory. This part measures the series count of the Tekton components, shows how the controller settings change it, and removes series that nobody reads.

## Count the series

Prometheus counts its own series, and a query counts the series of a job or a metric. The first query below counts all series per job, and the second lists the ten metric names with the most series for the Pipelines controller:

<!-- astrona:playground:renew -->

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=count by (job) ({job!=\"\"})" | jq -c ".data.result[] | [.metric.job, .value[1]]"'
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=topk(10, count by (__name__) ({job=\"tekton-pipelines-controller\"}))" | jq -c ".data.result[] | [.metric.__name__, .value[1]]"'
```

The metric `__name__` is the internal label that holds the metric name, and a selector like `{job="..."}` without a name matches every metric of the job. On a fresh playground the controller has few series. The histograms are the largest part once runs have finished: each histogram stores one `_bucket` series for every bucket bound, for every label combination, plus a `_sum` and a `_count`.

## See the levels at work

The ConfigMap `config-observability` sets the labels of the run metrics. The default `metrics.taskrun.level` is `task`, which keeps the label `task`, and the level `taskrun` adds the name of each run. Run three Tasks, change the level, and compare. Save this as `task-nightly-check.yaml`:

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

Apply it and start three runs:

```sh
kubectl apply -f task-nightly-check.yaml
for i in 1 2 3; do tkn task start nightly-check -n starfleet -p outcome=pass; done
```

Read the number of series of the duration histogram, after the next scrape:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=count({__name__=~\"tekton_pipelines_controller_taskrun_duration_seconds.*\"})" | jq -c ".data.result[] | .value[1]"'
```

Now change the level. Save this as `configmap-config-observability-patch.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-observability
  namespace: tekton-pipelines
data:
  metrics.taskrun.level: taskrun
```

Apply it, restart the controller, run three more Tasks, and count again:

```sh
kubectl apply -f configmap-config-observability-patch.yaml
kubectl rollout restart deployment/tekton-pipelines-controller -n tekton-pipelines
kubectl rollout status deployment/tekton-pipelines-controller -n tekton-pipelines
for i in 1 2 3; do tkn task start nightly-check -n starfleet -p outcome=pass; done
```

After the next scrape the count is higher, and the series now carry a `taskrun` label with the name of each run. Every new run adds all bucket series again under a new name. Prometheus keeps old series until the retention time passes, so the count only grows. Set the level back to `task` by deleting the key you added, then restart the controller:

```sh
kubectl patch configmap config-observability -n tekton-pipelines --type=json -p='[{"op":"remove","path":"/data/metrics.taskrun.level"}]'
kubectl rollout restart deployment/tekton-pipelines-controller -n tekton-pipelines
```

The `namespace` level goes the other way: it drops the `task` label, which gives fewer series and a coarser answer. Choose the lowest level that still answers the questions your alerts and dashboards ask.

## Drop series at scrape time

Sometimes a component serves metrics you never use. Prometheus can discard them before it stores them, with `metric_relabel_configs` in the scrape job. The block runs on every scraped series after the scrape. An `action: drop` rule with a `regex` on the label `__name__` removes every series whose metric name matches the regex.

The example below drops the gauge of running PipelineRuns from the controller job. Use it only as an experiment, because the gauge is useful in real life. Save this as `configmap-prometheus-config.yaml`:

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
        metric_relabel_configs:
          - source_labels: [__name__]
            regex: tekton_pipelines_controller_running_pipelineruns
            action: drop
  tekton-rules.yml: |
    groups: []
```

Apply it, restart Prometheus, and check that the series stopped. After the restart, wait one scrape interval:

```sh
kubectl apply -f configmap-prometheus-config.yaml
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout status deployment/prometheus -n monitoring
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=tekton_pipelines_controller_running_pipelineruns" | jq -c ".data.result | length"'
```

The last command prints `0`: Prometheus no longer stores the series, while `tekton_pipelines_controller_running_taskruns` is still there. The regex is anchored: Prometheus matches the whole value, so `running_pipelineruns` alone would match nothing.

### Relabel rules apply in order

`relabel_configs` runs before the scrape and decides which targets Prometheus scrapes and which labels they get. `metric_relabel_configs` runs after the scrape on each series. Mixing them up is the most common mistake: a rule on `__name__` in `relabel_configs` matches nothing, because a target has no metric name yet.

## Set a retention limit

Retention is the third control. The playground starts Prometheus with `--storage.tsdb.retention.time=1d`, so samples older than one day are deleted. The flag `--storage.tsdb.retention.size` caps the disk use instead. Prometheus removes the oldest blocks when either limit is reached. A cluster that needs long history keeps a short retention here and sends data to long-term storage, which is outside this module.

You can now count series per job and per metric, explain what the run metric levels do to the count, and drop series you do not use. The next question is how much of this a real installation needs, which depends on the questions its teams ask.

## Common pitfalls

> [!WARNING]
> - **Using the level `taskrun` or `pipelinerun` in production.** Every run adds a full set of histogram series with its own name.
> - **Forgetting to restart the controller.** It reads `config-observability` at start.
> - **Dropping a metric that an alert or dashboard uses.** The alert then never fires. Search your rules first.
> - **Using `relabel_configs` for a metric name.** Use `metric_relabel_configs`; the name exists only after the scrape.
> - **Expecting old series to vanish at once.** Prometheus deletes them only after the retention time.
