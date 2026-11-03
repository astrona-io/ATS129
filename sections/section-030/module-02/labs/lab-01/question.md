# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Monitoring

## Scenario

The `starfleet` team opens a dashboard every morning to see how many nightly checks failed, and the query behind it is slow because it adds up every series each time. The same team also wants to know when many runs pile up in the cluster. Prometheus in the namespace `monitoring` already scrapes the Tekton Pipelines controller, but it has no rules yet.

## Your task

1. Add a recording rule named `tekton:taskrun_failed:ratio` in a group named `tekton-recording`. It must store the share of failed TaskRuns among all TaskRuns counted by the controller:
   - `expr: sum(tekton_pipelines_controller_taskrun_total{status="failed"}) / sum(tekton_pipelines_controller_taskrun_total)`
2. Add an alerting rule named `TektonTooManyRunningTaskRuns` in a group named `tekton-alerts`. It must fire when more than two TaskRuns run at the same time for one minute:
   - `expr: tekton_pipelines_controller_running_taskruns > 2`
   - `for: 1m`
   - `labels: severity: warning`
3. Make Prometheus load the rules, and prove the alert with three long TaskRuns of the Task `slow-check`.

## Constraints

- Change Prometheus only through the ConfigMap `prometheus-config`. Keep the Deployment and the Service as they are.
- Keep both existing scrape jobs, `prometheus` and `tekton-pipelines-controller`.
- Write the rules in `tekton-rules.yml`, the rule file that `prometheus.yml` already names.

## Done when

- Prometheus has loaded the recording rule `tekton:taskrun_failed:ratio`, and the series of that name has a value above 0 and at most 1.
- Prometheus has loaded the alerting rule `TektonTooManyRunningTaskRuns` with the expression, the `for` time and the label above.
- While three TaskRuns of `slow-check` run, the alert `TektonTooManyRunningTaskRuns` is `firing` within four minutes.
