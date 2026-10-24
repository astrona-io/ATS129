# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Monitoring

## Scenario

The `starfleet` team learns about failed nightly checks only when someone opens the Dashboard. The platform team already runs Prometheus in the namespace `monitoring`, but it does not collect any Tekton metrics yet, and it has no alerts.

## Your task

1. Make Prometheus scrape the metrics of the Tekton Pipelines controller, in a scrape job named `tekton-pipelines-controller`.
2. Add an alerting rule named `TektonTaskRunFailed` to `tekton-rules.yml`, in a group named `tekton`. It must fire as soon as the controller has counted at least one failed TaskRun, with this expression and label:
   - `expr: sum(tekton_pipelines_controller_taskrun_total{status="failed"}) > 0`
   - `labels: severity: warning`
3. Make Prometheus load the new configuration, and prove the alert with a failed run of `nightly-check`.

## Constraints

- Change Prometheus only through the ConfigMap `prometheus-config`. Keep the Deployment and the Service as they are.
- Scrape the controller through its Service in `tekton-pipelines`; do not use a pod IP address.
- Keep the existing scrape job `prometheus`.

## Done when

- `up{job="tekton-pipelines-controller"}` is `1`.
- Prometheus stores `tekton_pipelines_controller_running_taskruns` from the job `tekton-pipelines-controller`.
- Prometheus has loaded the alerting rule `TektonTaskRunFailed` with the expression and label above.
- After a new TaskRun of `nightly-check` fails, the alert `TektonTaskRunFailed` is `firing` within three minutes.
