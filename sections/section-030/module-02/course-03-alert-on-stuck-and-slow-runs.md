# Alert On Stuck And Slow Runs

A failed run announces itself: the counter of failed TaskRuns goes up. A stuck run says nothing. It stays in the state `Running` because it waits for a pod that cannot be scheduled, a registry that does not answer, or a command that never ends. The failure counter stays flat, and the first sign is a team that asks why its build has not finished. This part writes alerts for the two quiet cases: too many runs at once, and runs that take much longer than before.

## The gauge of running runs

The controller exports `tekton_pipelines_controller_running_taskruns`, a gauge, which is a value that goes up and down. It holds the number of TaskRuns the controller currently counts as running. It has no `status` label, because a running TaskRun has no result yet. A gauge needs no `rate`: you compare it with a number directly.

Start the Task for this part. It sleeps for the number of seconds you give it. Save it as `task-slow-check.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: slow-check
  namespace: starfleet
spec:
  params:
    - name: seconds
      type: string
      default: "240"
  steps:
    - name: wait
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        echo "waiting $(params.seconds) seconds"
        sleep "$(params.seconds)"
```

Apply it and start three runs without waiting for the logs:

```sh
kubectl apply -f task-slow-check.yaml
for i in 1 2 3; do tkn task start slow-check -n starfleet -p seconds=300; done
```

Then read the gauge from Prometheus:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=tekton_pipelines_controller_running_taskruns" | jq -c ".data.result[] | .value[1]"'
```

While the three pods run, the value is `3` after the next scrape, which takes up to 15 seconds. When the runs end the gauge returns to `0`.

## Why an alert needs a for time

A single spike above a threshold is often normal: a pipeline with many parallel tasks starts many TaskRuns for a short time. An alert that fires at once would page someone for it. The `for` key in the rule tells Prometheus to keep the alert `pending` until the expression has been true at every evaluation for that whole time, and only then to make it `firing`. If the expression becomes false during the wait, the alert returns to `inactive` and the timer starts again.

Choose the `for` time from how long a harmless spike lasts. For a count of running runs, one to five minutes is common. For a controller that is down, two minutes is common, because a pod restart takes about that long.

## Write the rules

The rule file below has one alert for runs that pile up and one for runs that got slower. Save it as `configmap-prometheus-config.yaml`:

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
      - name: tekton-alerts
        rules:
          - alert: TektonTooManyRunningTaskRuns
            expr: tekton_pipelines_controller_running_taskruns > 2
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: More than two TaskRuns run at the same time
          - alert: TektonSlowTaskRuns
            expr: histogram_quantile(0.95, sum by (le) (rate(tekton_pipelines_controller_taskrun_duration_seconds_bucket[15m]))) > 120
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: The 95th percentile of TaskRun duration is above two minutes
```

Apply it and restart Prometheus:

```sh
kubectl apply -f configmap-prometheus-config.yaml
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout status deployment/prometheus -n monitoring
```

Wait for the three runs from before to end if they are still going, then start three new ones and follow the alert:

```sh
for i in 1 2 3; do tkn task start slow-check -n starfleet -p seconds=300; done
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/alerts | jq -r ".data.alerts[] | .labels.alertname + \" \" + .state"'
```

Run the second command several times. `TektonTooManyRunningTaskRuns` is `pending` for the first minute and `firing` after that. Prometheus restarted, so the gauge has no history from before; the alert starts from the first scrape.

## Read the duration alert

The duration metric is a histogram. A histogram stores, for each bucket, a counter named `..._bucket` with a label `le` (less than or equal), which holds the number of observations at or below that upper bound in seconds. The function `histogram_quantile(0.95, ...)` estimates from those buckets the value below which 95 percent of the observations fall. The inner `rate` over 15 minutes turns the bucket counters into a per-second rate, so the estimate covers only runs that finished in the window. `sum by (le)` merges all Tasks and namespaces into one histogram; add `task` to the `by` list for a result per Task.

Two properties matter. The estimate is only as precise as the bucket boundaries, so a threshold between two bucket bounds is rounded. And a run that has not finished is not in the histogram yet, so this alert reports slow runs after they end, while the running gauge reports runs that are still in progress. Use both.

## Tell the difference between down and silent

An alert on a metric cannot fire when the metric has no series. If the controller stops, `up{job="tekton-pipelines-controller"}` becomes `0`, but the Tekton series vanish after the staleness period, and an alert on `running_taskruns > 2` is silently inactive. Combine the rule with an availability alert on `up`, and use `absent` when a series should always exist:

```yaml
- alert: TektonRunningGaugeMissing
  expr: absent(tekton_pipelines_controller_running_taskruns)
  for: 5m
  labels:
    severity: critical
```

`absent(selector)` returns a single series with the value `1` when the selector matches nothing, and nothing when it matches at least one series. That makes it the right tool for "the metric is gone".

You can now alert on runs that pile up, on runs that slow down, and on a metric that disappears, each with a `for` time that fits the case. These rules need a Prometheus that is not drowning in series. The open question is where the series count comes from and how to cut it.

## Common pitfalls

> [!WARNING]
> - **No `for` time on a count alert.** One short spike pages someone.
> - **Trusting a threshold between bucket bounds.** The quantile is an estimate and is rounded to the bucket layout.
> - **Expecting a duration alert for a run that has not ended.** The histogram records a run only when it ends.
> - **Alerting only on values.** If the controller stops, the series disappear and the value alert cannot fire; add `up` and `absent`.
> - **Putting `rate` on a gauge.** `rate` is for counters; a gauge is compared directly.

## Your mission: Record Failure Ratio And Alert On Stuck TaskRuns

You can now write a recording rule and an alert on the running-runs gauge. The graded lab gives you a Prometheus that scrapes the controller but has no rules, and asks you to record the failure ratio, add the stuck-runs alert with a `for` time, and prove the alert with three long runs.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-129-playground-030-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-030/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-129-lab-030-02
astrona start ats-129-playground-030-02
```
