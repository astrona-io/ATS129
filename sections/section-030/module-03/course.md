# Route Tekton Alerts With Alertmanager

An alert rule in Prometheus only decides that something is wrong. It does not decide who hears about it. Alertmanager does that: it receives the alerts, groups them, drops duplicates, waits a short time, picks a receiver and repeats the message until the problem ends or someone silences it. Without a routing tree, every alert goes to one place and the pager rings for a warning at noon.

Keep one sentence in mind: **Prometheus decides when an alert fires, Alertmanager decides who is told, how often and whether it is told at all.** The two programs share only the alert labels, so the labels you put on a rule, such as `severity`, are the contract between them.

The module has four parts. **Read The Alertmanager Configuration** explains the route tree, the matchers and the grouping times. **Wire Prometheus To Alertmanager** shows how alerts travel between the two programs and how to watch them on the way. A graded lab follows that part. **Define Rules As Kubernetes Objects** shows how the Prometheus Operator turns a ServiceMonitor and a PrometheusRule into scrape jobs and rule files. **Silence And Inhibit Alerts** stops noise on purpose, for a maintenance window or when one failure explains many alerts.

## Learning objectives

After this module you can:

- Read an Alertmanager route tree and say which receiver a set of labels reaches, with `amtool config routes test`.
- Set `group_by`, `group_wait`, `group_interval` and `repeat_interval` for a route and explain what each one changes.
- Point Prometheus at Alertmanager with `alerting.alertmanagers`, and follow an alert from `pending` to `firing` to delivered.
- Describe what a ServiceMonitor and a PrometheusRule are, and which part of a plain Prometheus setup each one replaces.
- Create and expire a silence, and write an inhibition rule that mutes warnings while a critical alert for the same problem fires.

## Before you start

You need to know what a Prometheus alerting rule is and what labels are. In short: an alerting rule is a PromQL expression with a name, an optional `for` time and labels; every alert it creates carries those labels plus the labels of the series that matched.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1, with the Pruner v0.4.4 |
| `deploy/prometheus` in `monitoring` | Prometheus v3.15.1 with two alerts: `TektonTooManyRunningTaskRuns` (warning) and `TektonControllerDown` (critical). It sends them to Alertmanager |
| `deploy/alertmanager` in `monitoring` | Alertmanager v0.28.1 with the config from the ConfigMap `alertmanager-config`: one receiver and no child routes |
| `deploy/client` in `monitoring` | A pod with `curl` and `jq` |
| Namespace `starfleet` | Empty. Your Tasks and TaskRuns go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
