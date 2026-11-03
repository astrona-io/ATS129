# Solution: Record Failure Ratio And Alert On Stuck TaskRuns

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the recording rule is loaded and stores a value; the alerting rule is loaded with the right query, `for` time and label; and the alert fires while three TaskRuns run.

## Step 1: Read the starting state

```sh
kubectl get configmap prometheus-config -n monitoring -o jsonpath='{.data.tekton-rules\.yml}'
kubectl get taskruns -n starfleet
```

The rule file holds `groups: []`, so Prometheus loads no rules. The namespace `starfleet` has one passed and one failed run of `nightly-check`, so the controller already counts both statuses.

## Step 2: Write the rules

Both rules go in `tekton-rules.yml` in the ConfigMap `prometheus-config`. Keep `prometheus.yml` as it is. Save this as `configmap-prometheus-config.yaml`:

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
        rules:
          - record: tekton:taskrun_failed:ratio
            expr: sum(tekton_pipelines_controller_taskrun_total{status="failed"}) / sum(tekton_pipelines_controller_taskrun_total)
      - name: tekton-alerts
        rules:
          - alert: TektonTooManyRunningTaskRuns
            expr: tekton_pipelines_controller_running_taskruns > 2
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: More than two TaskRuns run at the same time
```

Apply it:

```sh
kubectl apply -f configmap-prometheus-config.yaml
```

## Step 3: Restart Prometheus

Prometheus reads its files only when it starts:

```sh
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout status deployment/prometheus -n monitoring
```

## Step 4: Check the rules

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/rules | jq -r ".data.groups[] | .name as \$group | .rules[] | \$group + \" \" + .type + \" \" + .name + \" \" + .health"'
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=tekton:taskrun_failed:ratio" | jq -c ".data.result[] | .value[1]"'
```

The first command lists both rules with the health `ok` after the first evaluation. The second prints the recorded value. With one failed and one passed run the ratio is `0.5`.

## Step 5: Make the alert fire

Start three slow runs and follow the alert:

```sh
for i in 1 2 3; do tkn task start slow-check -n starfleet -p seconds=300; done
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/alerts | jq -r ".data.alerts[] | .labels.alertname + \" \" + .state"'
```

Run the second command a few times. The alert is `pending` while the gauge is above 2, and `firing` once it has been above 2 for one minute.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Put the rules in `prometheus.yml` | Prometheus rejects a `groups` block in the main file and does not start |
| Leave out `for: 1m` | The alert fires at once, and the grader checks the `for` time |
| Use `>= 2` | Two parallel runs are normal here; the rule must fire above two |
| Do not restart Prometheus | It keeps the old rule file |

## Common mistakes

- Writing a record name with a space or a dash. Use letters, digits, underscores and colons.
- Dividing by `tekton_pipelines_controller_taskrun_total` without `sum`. The two sides then match series by labels, and the result is a different number.
- Waiting for the alert while the three runs are already over. Keep the runs alive with a long `seconds` value.
