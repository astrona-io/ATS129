# Solution: Repair Tekton Monitoring

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the controller exports Prometheus metrics again; the job `tekton-pipelines-controller` is up; the rule `TektonTaskRunFailed` selects `status="failed"` with `severity: warning`; and the alert fires after a TaskRun fails.

## Step 1: Read what Prometheus sees

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/targets | jq -r ".data.activeTargets[] | .labels.job + \" \" + .scrapeUrl + \" \" + .health + \" \" + .lastError"'
```

The job `tekton-pipelines-controller` is `down`, and its scrape address ends in `:8080/metrics`. Port `8080` of the controller Service is named `probes`; the metrics port is `http-metrics`, port `9090`:

```sh
kubectl get service tekton-pipelines-controller -n tekton-pipelines -o jsonpath='{range .spec.ports[*]}{.name}={.port}{"\n"}{end}'
```

## Step 2: The Tekton side

Before you fix Prometheus, check that the controller serves metrics at all, through the API server proxy:

```sh
kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pipelines-controller:http-metrics/proxy/metrics | head -n 5
kubectl get configmap config-observability -n tekton-pipelines -o jsonpath='{.data.metrics-protocol}{"\n"}'
```

The first command returns no Tekton metrics (or an error, because nothing listens on port `9090`). The second prints `none`. With `metrics-protocol: none`, the controller exports no metrics at all. Set it back to `prometheus`, which starts the HTTP server on port `9090`, and restart the controller so it builds its metrics exporter again:

```sh
kubectl patch configmap config-observability -n tekton-pipelines --type merge -p '{"data":{"metrics-protocol":"prometheus"}}'
kubectl rollout restart deployment/tekton-pipelines-controller -n tekton-pipelines
kubectl rollout status deployment/tekton-pipelines-controller -n tekton-pipelines
kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pipelines-controller:http-metrics/proxy/metrics | grep '^tekton_pipelines_controller_running_taskruns'
```

The last command prints the gauge `tekton_pipelines_controller_running_taskruns`.

## Step 3: The Prometheus side

Read the rule as Prometheus loaded it:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/rules | jq -r ".data.groups[].rules[] | .name + \": \" + .query"'
```

The rule compares `status` with `failure`. The controller writes only `success`, `failed` and `cancelled` into that label, so the selector never matches and the alert can never fire. Fix the port and the value in one ConfigMap. Save this as `configmap-prometheus-config.yaml`:

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
      - name: tekton
        rules:
          - alert: TektonTaskRunFailed
            expr: sum(tekton_pipelines_controller_taskrun_total{status="failed"}) > 0
            labels:
              severity: warning
            annotations:
              summary: A TaskRun failed
```

Apply it, and restart Prometheus so it reads the files:

```sh
kubectl apply -f configmap-prometheus-config.yaml
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout status deployment/prometheus -n monitoring
```

## Step 4: Prove it

```sh
tkn task start nightly-check -n starfleet -p outcome=fail --showlog
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/alerts | jq -r ".data.alerts[] | .labels.alertname + \" \" + .state"'
```

Within about 30 seconds the second command prints `TektonTaskRunFailed firing`. Run it again if it prints nothing yet.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Fix only the port | The controller exports nothing while `metrics-protocol` is `none`; the target stays down |
| Fix only `config-observability` | Prometheus still scrapes the `probes` port |
| Change the alert to `status!="success"` | It also fires for cancelled runs; the grader requires `status="failed"` |
| Scrape the controller pod's IP address | The address changes with every restart of the controller |
| Edit the ConfigMap without restarting Prometheus | Prometheus keeps the files it read at start |

## Common mistakes

- Trusting the alert's `inactive` state. An alert whose selector matches nothing is always `inactive`; test it with a real failure.
- Changing `config-observability` without restarting the controller. Restart it so it builds its exporter with the new protocol.
- Reading `up` before the first scrape. Wait one scrape interval, 15 seconds here.

## Practice on your own

- Add `metrics.count.enable-reason: "true"` to `config-observability`, restart the controller, and find the `reason` label on the duration metric.
- Set `metrics.taskrun.level` to `taskrun` and see how many series the duration metric gets.
- Add a rule that fires when `up{job="tekton-pipelines-controller"} == 0` for one minute, and scale the controller to zero to test it.
