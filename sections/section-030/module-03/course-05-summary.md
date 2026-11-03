# Summary

Alerting has two halves. Prometheus evaluates rules and decides that an alert fires; Alertmanager decides who is told, how often and whether the message is sent at all. The labels on the alert, above all `severity`, are what connects them.

## What you learned

The Alertmanager configuration is a route tree plus a list of receivers. An alert enters at the root and goes into the first child whose matchers match, and children inherit `receiver`, `group_by` and the timing settings from their parent. `group_wait` delays the first message of a group, `group_interval` the next news about it and `repeat_interval` the repetition of an unchanged group. A receiver has a name and zero or more integrations such as a webhook. `amtool check-config` finds errors in a file and `amtool config routes test` shows the receiver for any labels without a live alert. Alertmanager reads its file at start or on reload, so a ConfigMap change needs a restart.

Prometheus pushes alerts to the addresses in `alerting.alertmanagers`. Only firing alerts are sent, so the `for` time delays the first message, and `/api/v2/alerts` on Alertmanager shows which receivers a route chose. When an alert is missing, check the Prometheus state, the link, the Alertmanager list, the route, silences and the log, in that order. With the Prometheus Operator, a ServiceMonitor replaces a scrape job and a PrometheusRule replaces a rule file; their selectors and the Service port name decide whether they work. A silence mutes alerts for a chosen time, and an inhibition rule mutes targets while a source alert fires and the `equal` labels match. The key facts to remember are these:

- First matching child wins, unless `continue: true`.
- Test routing with `amtool config routes test`, and read delivery in `/api/v2/alerts`.
- A ServiceMonitor `port` is the Service port name, and the Prometheus object picks objects by label.
- Silences need matchers, an end and a comment; inhibition needs `equal`.

<!-- astrona:playground:destroy -->
