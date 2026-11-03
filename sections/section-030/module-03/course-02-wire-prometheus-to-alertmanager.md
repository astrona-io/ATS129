# Wire Prometheus To Alertmanager

Prometheus and Alertmanager are two programs. Prometheus evaluates the rules and pushes the alerts it has; Alertmanager never queries Prometheus. This part follows an alert across that link, so you know where to look when an alert fires and nobody hears it.

## How Prometheus finds Alertmanager

The `alerting` block of `prometheus.yml` lists the Alertmanager instances. Print the playground's file:

<!-- astrona:playground:renew -->

```sh
kubectl get configmap prometheus-config -n monitoring -o jsonpath='{.data.prometheus\.yml}'
```

The block looks like this:

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager.monitoring.svc:9093"]
```

Prometheus sends every firing alert to each target at `/api/v2/alerts`. With several Alertmanager instances in a cluster, list all of them; Prometheus sends to each one, and the instances share silences and notification state through their own gossip. An optional `alert_relabel_configs` block can rewrite or drop alert labels before they are sent, and `external_labels` in the `global` block adds labels such as `cluster` to every alert.

Ask Prometheus which instances it uses:

```sh
kubectl exec -n monitoring deploy/client -- curl -s http://prometheus.monitoring:9090/api/v1/alertmanagers | jq .data.activeAlertmanagers
```

An empty list means Prometheus cannot see Alertmanager. The cause is the target address, the Service name or a network policy, not a rule.

## The life of an alert

An alerting rule has three states in Prometheus:

1. **inactive**: the expression returns nothing.
2. **pending**: the expression returns a series, but the `for` time has not passed. Pending alerts are not sent to Alertmanager.
3. **firing**: the expression has returned the series for the whole `for` time. Prometheus sends the alert and keeps resending it every minute (the default `--rules.alert.resend-delay`) while it fires.

The `for` time therefore delays the first message, and `group_wait` in Alertmanager delays it a second time. For `TektonTooManyRunningTaskRuns` with `for: 1m` and a route with `group_wait: 10s`, the first notification can be about 70 seconds after the third run starts, plus up to one evaluation interval.

## Watch an alert on both sides

Read the alerts Prometheus holds:

```sh
kubectl exec -n monitoring deploy/client -- curl -s http://prometheus.monitoring:9090/api/v1/alerts | jq -c '.data.alerts[] | [.labels.alertname, .state]'
```

Read the alerts Alertmanager holds:

```sh
kubectl exec -n monitoring deploy/client -- curl -s http://alertmanager.monitoring:9093/api/v2/alerts | jq -c '.[] | [.labels.alertname, .status.state, [.receivers[].name]]'
```

Each entry on the Alertmanager side lists the receivers its route chose. This is the place to see whether routing did what you wanted, even when the receiver URL does not exist. Start three long runs to raise the warning alert:

```sh
for i in 1 2 3; do tkn task start slow-check -n starfleet; done
```

Wait for the `for` time and read both lists again. The alert shows `pending`, then `firing` on the Prometheus side, and appears on the Alertmanager side when it fires.

## Find out why an alert did not arrive

Work from the rule outwards:

1. In Prometheus, is the alert `firing`, or only `pending`? A pending alert has not waited its `for` time.
2. Does `/api/v1/alertmanagers` list an active instance? If not, fix `alerting` and restart Prometheus.
3. Does Alertmanager list the alert at `/api/v2/alerts`? If yes, the link works; look at routing.
4. Which receiver does the alert list, and does `amtool config routes test` agree for its labels?
5. Is the alert silenced or inhibited? The status in `/api/v2/alerts` shows `suppressed` with the silence or inhibiting alert IDs.
6. Does the notification fail? The Alertmanager log names the receiver and the error.

```sh
kubectl logs -n monitoring deploy/alertmanager --tail=20
```

A webhook to a host that does not resolve logs a delivery error for that receiver; the routing is still right.

## What to remember

- Prometheus pushes alerts to Alertmanager; the target list is `alerting.alertmanagers`.
- Only firing alerts are sent; `for` delays the first message.
- `/api/v2/alerts` on Alertmanager shows the receivers a route chose.
- Check the alerts in this order: Prometheus state, link, Alertmanager list, routing, silences, delivery.

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-129-lab-030-03
astrona start ats-129-playground-030-03
```
