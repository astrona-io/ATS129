# Precompute Queries With Recording Rules

A dashboard panel runs its query every time someone opens the page, and an alert runs its query at every rule evaluation. When the query adds up thousands of series, each run costs CPU time and slows the page. A recording rule moves that work out of the page: Prometheus evaluates the query once per interval and stores the result as a new, small time series. This part writes recording rules for Tekton and explains how to name and read them.

## What a recording rule is

A rule file holds groups, and a group holds rules that Prometheus evaluates in order at the group's interval. An alerting rule has the key `alert`. A recording rule has the key `record` instead: its value is the name of the new series, and `expr` is the query whose result Prometheus stores under that name at every evaluation. The new series has the labels of the query result, plus any labels you add under `labels`.

Because the result is a normal series, other rules and queries can use it. A dashboard that reads `tekton:taskrun_failed:ratio` reads one stored value, not the sum over every status series.

## Name the series by convention

Prometheus names a recorded series `level:metric:operations`. The level lists the labels the series keeps. The metric is the original metric name, and the operations list the functions that were applied, newest first. The colon is allowed only in recorded names; instrumented metrics never use it, so a colon tells every reader that a rule produced the series.

For Tekton, `tekton:taskrun_failed:ratio` reads as: across the whole controller (no labels kept), the failed TaskRuns as a ratio. A per-namespace version would be `namespace:tekton_taskrun_failed:ratio`.

## Write a recording rule

Run one passing and one failing TaskRun first, so the counters hold both statuses. Save this as `task-nightly-check.yaml`:

<!-- astrona:playground:renew -->

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

Apply it and start the two runs:

```sh
kubectl apply -f task-nightly-check.yaml
tkn task start nightly-check -n starfleet -p outcome=pass --showlog
tkn task start nightly-check -n starfleet -p outcome=fail --showlog
```

Now put the rule in the rule file. Save this as `configmap-prometheus-config.yaml`; the scrape part is the same as before, and only `tekton-rules.yml` is new:

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
    groups:
      - name: tekton-recording
        interval: 30s
        rules:
          - record: tekton:taskrun_failed:ratio
            expr: sum(tekton_pipelines_controller_taskrun_total{status="failed"}) / sum(tekton_pipelines_controller_taskrun_total)
          - record: status:tekton_taskrun_total:sum
            expr: sum by (status) (tekton_pipelines_controller_taskrun_total)
```

The `interval` key on the group overrides the global `evaluation_interval` for this group only. Apply the file and restart Prometheus:

```sh
kubectl apply -f configmap-prometheus-config.yaml
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout status deployment/prometheus -n monitoring
```

Then read the recorded series after the first evaluation, which takes up to 30 seconds:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=tekton:taskrun_failed:ratio" | jq -c ".data.result[] | [.metric, .value[1]]"'
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=status:tekton_taskrun_total:sum" | jq -c ".data.result[] | [.metric.status, .value[1]]"'
```

With one passed and one failed run the first query returns `0.5`, and the second returns one series for `success` and one for `failed`. The ratio is a share of all runs since the controller started, because the counters only count up.

## Rate-based rules for trends

The plain ratio never forgets old runs, so it moves slowly after weeks of operation. For a trend, record a rate over a window. A `rate` of a counter gives the per-second increase averaged over the window, and the division of two rates gives the share of failures in that window:

```yaml
- record: tekton:taskrun_failed:ratio_rate30m
  expr: sum(rate(tekton_pipelines_controller_taskrun_total{status="failed"}[30m])) / sum(rate(tekton_pipelines_controller_taskrun_total[30m]))
```

The name carries the window, so two rules with different windows do not collide. When no run happened in the window, both rates are zero and the division returns `NaN` for that evaluation, which is why dashboards often add a condition before they plot it.

## Check that a rule works

The rules API lists every loaded rule with its health, its last evaluation time and any error:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/rules | jq -r ".data.groups[].rules[] | .type + \" \" + .name + \" \" + .health"'
```

A rule that reports the health `err` has a `lastError` field. The usual cause is a query that references a metric that does not exist yet. A recording rule over a missing metric returns an empty result and records nothing, without an error, so always read the recorded series itself once.

You can now store the answer of a query as a series, name it by convention, and prove that it holds a value. The rule file can hold alerting rules next to recording rules. The open question is how to alert on runs that never finish or finish too slowly.

## Common pitfalls

> [!WARNING]
> - **A recorded name without the colon convention.** Without a colon, a reader takes the series for an instrumented metric.
> - **Putting a rule group in `prometheus.yml`.** Rule groups belong in a file named in `rule_files`.
> - **Recording a query that returns nothing.** The rule shows health `ok` and records no series. Read the series back.
> - **Dividing by a counter that is zero.** The result is `NaN`, not zero.
> - **Windows shorter than twice the scrape interval.** A `rate` needs at least two samples inside the window.
