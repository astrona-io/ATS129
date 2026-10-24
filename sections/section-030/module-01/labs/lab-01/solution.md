# Solution: Scrape Tekton And Alert On Failed TaskRuns

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the target of the job `tekton-pipelines-controller` is up; Prometheus stores real Tekton metrics from it; the rule `TektonTaskRunFailed` is loaded with the right query and label; and the alert fires after a TaskRun fails.

## Step 1: Find the metrics endpoint

```sh
kubectl get service tekton-pipelines-controller -n tekton-pipelines -o jsonpath='{range .spec.ports[*]}{.name}={.port}{"\n"}{end}'
kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pipelines-controller:http-metrics/proxy/metrics | grep '^tekton_pipelines_controller_' | head -n 5
```

The Service has three ports: `http-metrics` on `9090`, `http-profiling` on `8008` and `probes` on `8080`. The second command reads `/metrics` through the API server proxy and shows the first lines of Tekton metrics, so the controller serves them on port `9090`. Inside the cluster, Prometheus reaches that port as `tekton-pipelines-controller.tekton-pipelines.svc:9090`.

## Step 2: Write the new configuration

The scrape job and the rule both live in the ConfigMap `prometheus-config`. Save this as `configmap-prometheus-config.yaml`:

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

Apply it:

```sh
kubectl apply -f configmap-prometheus-config.yaml
```

## Step 3: Restart Prometheus

Prometheus reads its configuration files only when it starts, and the new pod mounts the current ConfigMap:

```sh
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout status deployment/prometheus -n monitoring
```

## Step 4: Check the target and the rule

Run the checks from the client pod, which has `curl` and `jq`:

```sh
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/targets | jq -r ".data.activeTargets[] | .labels.job + \" \" + .health"'
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/rules | jq -r ".data.groups[].rules[] | .name + \" \" + .state"'
```

Both jobs report `up` (after the first scrape, up to 15 seconds), and the rule `TektonTaskRunFailed` is `inactive`: no TaskRun has failed yet.

## Step 5: Make it fire

```sh
tkn task start nightly-check -n starfleet -p outcome=fail --showlog
kubectl exec -n monitoring deploy/client -- sh -c 'curl -s http://prometheus.monitoring:9090/api/v1/alerts | jq -r ".data.alerts[] | .labels.alertname + \" \" + .state"'
```

The run fails. Within about 30 seconds (one scrape plus one rule evaluation) the second command prints `TektonTaskRunFailed firing`. The rule has no `for:` clause, so it skips the `pending` state.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Scrape port `8080` | That is the `probes` port; `/metrics` is not there, and the target is down |
| Scrape a pod IP address | The address changes when the controller pod restarts |
| Use `status="failure"` or `status="Failed"` | The controller writes `success`, `failed` or `cancelled`; the alert never fires |
| Use `expr: vector(1)` to make it fire | The grader checks the query of the rule |
| Edit the ConfigMap but not restart Prometheus | Prometheus keeps the old files; nothing changes |

## Common mistakes

- Forgetting `rule_files`. The rule file exists in the ConfigMap, but Prometheus loads only the files that `rule_files` names.
- Indenting the rule wrongly. If Prometheus cannot parse a file at start, the pod does not become ready; read `kubectl logs -n monitoring deploy/prometheus`.
- Expecting `increase(...)` to see the first failure. A counter series that starts at 1 has no increase within its first sample; this is why the task uses `> 0`.

## Practice on your own

- Add a second alert for TaskRuns that run longer than five minutes, using `tekton_pipelines_controller_taskrun_duration_seconds`.
- Add `for: 1m` to the rule, fail a run, and watch the alert go from `pending` to `firing`.
- Scrape the Chains or Pruner controller as well; both serve metrics on port `9090` of their Service.
