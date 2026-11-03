# Solution: Route Tekton Alerts With Alertmanager

Work the task yourself first. Running `astrona submit -c sections/section-030/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: `amtool` routes the three severities to the right receivers; the loaded configuration has the grouping and the times; and a live warning alert is assigned to `platform-oncall`.

## Step 1: Read the starting state

```sh
kubectl get configmap alertmanager-config -n monitoring -o jsonpath='{.data.alertmanager\.yml}'
```

The file has the root route with `team-default` and no child routes.

## Step 2: Write the route tree and the receivers

Save this as `configmap-alertmanager-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    route:
      receiver: team-default
      group_by: [alertname]
      routes:
        - matchers:
            - severity="warning"
          receiver: platform-oncall
          group_by: [alertname]
          group_wait: 10s
          repeat_interval: 4h
        - matchers:
            - severity="critical"
          receiver: pager
          group_by: [alertname]
          repeat_interval: 1h
    receivers:
      - name: team-default
      - name: platform-oncall
        webhook_configs:
          - url: http://oncall.example.invalid/hook
      - name: pager
        webhook_configs:
          - url: http://pager.example.invalid/hook
```

```sh
kubectl apply -f configmap-alertmanager-config.yaml
```

## Step 3: Restart Alertmanager

```sh
kubectl rollout restart deployment/alertmanager -n monitoring
kubectl rollout status deployment/alertmanager -n monitoring
```

## Step 4: Test the routes

```sh
kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 config routes test severity=warning
kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 config routes test severity=critical
kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 config routes test severity=info
```

The three commands print `platform-oncall`, `pager` and `team-default`.

## Step 5: Watch a live alert

Start three long runs and look at Alertmanager after the one-minute `for` time of the alert has passed:

```sh
for i in 1 2 3; do tkn task start slow-check -n starfleet; done
kubectl -n monitoring exec deploy/client -- curl -s http://alertmanager.monitoring:9093/api/v2/alerts | jq '.[] | {alert: .labels.alertname, receivers: [.receivers[].name]}'
```

The alert `TektonTooManyRunningTaskRuns` lists `platform-oncall`. The webhook URL does not resolve, so delivery fails and Alertmanager logs it; the routing is what the grader checks.
