# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Monitoring

## Scenario

Last month a broken base image made every nightly check of the `starfleet` team fail for three days, and the alert `TektonTaskRunFailed` never fired. The platform team says Prometheus has had a Tekton scrape job and the alert all along. Someone also "tuned" the Tekton installation to save resources.

## Your task

1. Find out why Prometheus has no Tekton metrics. There is a fault on the Tekton side and one on the Prometheus side.
2. Find out why the alert `TektonTaskRunFailed` would not fire even with metrics, and fix it.
3. Prove the repair with a failed run of `nightly-check`.

## Constraints

- Keep the scrape job name `tekton-pipelines-controller`, and scrape the controller through its Service in `tekton-pipelines`.
- Keep the alert name `TektonTaskRunFailed`, its group `tekton`, the label `severity: warning` and the query shape `sum(tekton_pipelines_controller_taskrun_total{...}) > 0`.
- Change Prometheus only through the ConfigMap `prometheus-config`.
- Do not reinstall Tekton Pipelines.

## Done when

- `config-observability` in `tekton-pipelines` has `metrics-protocol: prometheus`, and the controller serves `tekton_pipelines_controller_running_taskruns` on its `http-metrics` port.
- `up{job="tekton-pipelines-controller"}` is `1`.
- The rule `TektonTaskRunFailed` selects `tekton_pipelines_controller_taskrun_total` with `status="failed"` and carries `severity: warning`.
- After a new TaskRun of `nightly-check` fails, the alert `TektonTaskRunFailed` is `firing` within three minutes.
