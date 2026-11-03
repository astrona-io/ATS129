# Silence And Inhibit Alerts

Some alerts should not reach anybody: a node is in a planned upgrade, or a total outage already explains twenty smaller alerts. Alertmanager has two tools for this. A **silence** mutes alerts for a time that a person chooses. An **inhibition rule** mutes alerts automatically while another alert fires. Both hide notifications; neither stops Prometheus from evaluating the rule.

## Silence for a maintenance window

A silence has matchers, a start, an end, an author and a comment. Any alert whose labels match is muted until the silence ends or is expired. Create one for the controller alert:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 silence add alertname=TektonControllerDown --duration=1h --author=training --comment="planned controller upgrade"
```

The command prints the ID of the silence. List the active ones:

```sh
kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 silence query
```

Silences live in Alertmanager's own storage, not in the configuration file, so a restart of a single-replica Deployment without a volume loses them. Keep the matchers as narrow as possible: a silence on `severity="critical"` hides every critical alert, not only the one you meant.

When the work is done, expire it so alerts can be sent again:

```sh
kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 silence expire <ID>
```

Replace `<ID>` with the ID that `silence query` shows.

A silenced alert is still in `/api/v2/alerts`. Its status is `suppressed` and it lists the IDs of the silences that mute it. Prometheus still shows it as `firing`.

## Inhibit warnings while a critical alert fires

If the controller is down, `TektonTooManyRunningTaskRuns` or any other symptom is noise: the cause is already reported. An inhibition rule names a source alert, a target alert and the labels that must be equal:

```yaml
inhibit_rules:
  - source_matchers:
      - severity="critical"
    target_matchers:
      - severity="warning"
    equal: [namespace]
```

While an alert that matches `source_matchers` fires, alerts that match `target_matchers` and have the same value for every label in `equal` are muted. Three rules help avoid surprises:

- Without `equal`, the source mutes the targets everywhere. List the labels that tie the two alerts to the same problem, such as `namespace` or `cluster`.
- An alert never inhibits itself, so a source and a target that both match the same alert do not hide it.
- The labels in `equal` should exist on both alerts. Check that both rules really set them, or the inhibition may never apply.

Inhibition lives in the configuration file, at the top level next to `route` and `receivers`. Add it the same way as routes: edit the ConfigMap, run `check-config` and restart Alertmanager.

## Silence or inhibit?

| Situation | Use |
| --- | --- |
| A person knows a change will cause alerts for a known time | Silence, with an end time and a comment |
| One failure always causes a known second kind of alert | Inhibition rule |
| An alert is wrong and should not exist | Fix or delete the rule in Prometheus |
| An alert is right but goes to the wrong person | Fix the route |

Silences with no end time and inhibition rules without `equal` are the two common ways that real problems stay hidden. Review the output of `silence query` as part of every maintenance.

## What to remember

- A silence mutes by matchers for a time; create it with `amtool silence add` and remove it with `silence expire`.
- An inhibition rule needs `source_matchers`, `target_matchers` and, in nearly every case, `equal`.
- Muted alerts stay visible with the status `suppressed`; Prometheus still shows them as firing.
- Do not use silences to hide a rule that is wrong.
