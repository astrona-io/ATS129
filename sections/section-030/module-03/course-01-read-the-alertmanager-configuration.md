# Read The Alertmanager Configuration

An Alertmanager configuration file has two main parts: a tree of routes that decides where an alert goes, and a list of receivers that say how to notify. This part reads both in the playground, then changes the tree and tests it without waiting for a real alert.

## Look at the file the playground starts with

The configuration lives in a ConfigMap and is mounted as `alertmanager.yml`. Print it:

<!-- astrona:playground:renew -->

```sh
kubectl get configmap alertmanager-config -n monitoring -o jsonpath='{.data.alertmanager\.yml}'
```

It has a `route` with `receiver: team-default` and a `receivers` list with one name, `team-default`, that has no notification settings. A receiver without settings accepts alerts and tells nobody. That is useful for tests, and it is why this setup never pages anyone.

## The route tree

The `route` block is the root of a tree. Every alert enters at the root and walks down:

- The root has no `matchers`, so it matches every alert. It must name a `receiver`, and that receiver is the fallback.
- A child route sits under `routes`. It has `matchers`, a list of label conditions such as `severity="critical"` or `alertname=~"Tekton.*"`. The operators are `=`, `!=`, `=~` and `!~`, and the last two take a regular expression that must match the whole value.
- An alert goes into the **first** child whose matchers all match. Alertmanager then looks at the children of that child in the same way. If no child matches, the alert stays with the parent.
- With `continue: true` on a child, the alert is also tried against the next sibling, which lets one alert reach two receivers.
- A child **inherits** `receiver`, `group_by`, `group_wait`, `group_interval` and `repeat_interval` from its parent and may override any of them.

Because the first match wins, put the most specific route first. A route for `severity="critical"` placed after a route for `alertname=~".*"` would never be used.

## Grouping and the three clocks

Alertmanager collects alerts into groups so one incident sends one message. Four settings control it:

| Setting | What it does | Default |
| --- | --- | --- |
| `group_by` | The labels whose values define a group. Alerts with the same values go in one notification. The special value `['...']` groups by all labels, which turns grouping off | the root route needs it set, or all alerts form one group |
| `group_wait` | How long to wait after the first alert of a new group before sending, so related alerts can join | `30s` |
| `group_interval` | How long to wait before sending news about a group that already notified, for example a new alert in it | `5m` |
| `repeat_interval` | How long to wait before sending the same, unchanged group again while it still fires | `4h` |

A short `group_wait` makes the first message fast but may split an incident into several messages. A short `repeat_interval` repeats a page that someone already knows about. Critical routes usually repeat sooner than warning routes, because an ignored critical alert is a bigger risk.

## Receivers

Each entry in `receivers` has a `name` and zero or more notification integrations, such as `webhook_configs`, `email_configs`, `slack_configs` or `pagerduty_configs`. A webhook receiver is the simplest to show:

```yaml
receivers:
  - name: pager
    webhook_configs:
      - url: http://pager.example.invalid/hook
```

Alertmanager sends a POST with a JSON body to the URL. The names of receivers are what routes refer to, and `amtool` reports them too.

## Check and test a file

`amtool` ships in the Alertmanager image. `check-config` loads a file and reports syntax errors and unknown receivers:

```sh
kubectl -n monitoring exec deploy/alertmanager -- amtool check-config /etc/alertmanager/alertmanager.yml
```

`config routes show` prints the tree, and `config routes test` takes labels and prints the receiver they reach. Without a file argument, `amtool` asks the running server for its configuration:

```sh
kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 config routes show
kubectl -n monitoring exec deploy/alertmanager -- amtool --alertmanager.url=http://localhost:9093 config routes test severity=critical
```

In the starting state both labels reach `team-default`, because the tree has only the root. The test needs no firing alert, which makes it the fastest way to check a routing change.

## Change the file safely

Alertmanager reads the file at start and when it gets a reload request. In the playground the file comes from a ConfigMap, so the sequence is: edit the ConfigMap, then restart the Deployment so the new file is read.

```sh
kubectl rollout restart deployment/alertmanager -n monitoring
kubectl rollout status deployment/alertmanager -n monitoring
```

A file with an error stops Alertmanager from starting, and the old pod keeps running while the new pod fails. Run `check-config` on the new text before you apply it, and read `kubectl rollout status` after.

## What to remember

- The route tree is walked from the root; the first matching child wins unless it has `continue: true`.
- Children inherit the settings of their parent.
- `group_wait`, `group_interval` and `repeat_interval` are three separate clocks.
- `amtool config routes test` shows the receiver for any labels without a live alert.
