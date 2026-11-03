# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Monitoring

## Scenario

Prometheus in the namespace `monitoring` evaluates two Tekton alerts, `TektonTooManyRunningTaskRuns` (severity `warning`) and `TektonControllerDown` (severity `critical`), and sends them to Alertmanager. Alertmanager has one receiver, `team-default`, and no routes, so every alert reaches the same place and nobody is paged. The `starfleet` team wants warnings to go to the platform on-call channel and critical alerts to the pager, with different repeat times.

## Your task

Change the Alertmanager configuration so that:

1. Alerts with the label `severity="warning"` go to a receiver named `platform-oncall`. The route groups by `alertname`, waits `10s` before the first notification (`group_wait`) and repeats every `4h` (`repeat_interval`).
2. Alerts with the label `severity="critical"` go to a receiver named `pager`. The route groups by `alertname` and repeats every `1h`.
3. All other alerts keep going to `team-default`, which stays the default receiver of the root route.
4. `platform-oncall` and `pager` are webhook receivers. Use `http://oncall.example.invalid/hook` and `http://pager.example.invalid/hook` as the URLs.

## Constraints

- Change Alertmanager only through the ConfigMap `alertmanager-config`. Keep the Deployment and the Service as they are.
- Do not change Prometheus.
- Alertmanager reads its file at start, so make the new file take effect.

## Done when

- `amtool config routes test` sends `severity=warning` to `platform-oncall`, `severity=critical` to `pager` and `severity=info` to `team-default`.
- The loaded configuration shows the grouping, the `group_wait` and the `repeat_interval` values above.
- While three TaskRuns of the Task `slow-check` run, the alert `TektonTooManyRunningTaskRuns` reaches Alertmanager and is assigned to the receiver `platform-oncall`.
