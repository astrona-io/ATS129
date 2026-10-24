# Delete Old Runs With TTLs And Namespace Settings

A count of runs is the wrong rule for many teams. A compliance team must keep build records for 30 days; a test team wants its runs gone after five minutes. One cluster-wide rule cannot serve both. This part deletes runs by age with a time to live (TTL), and lets each namespace set its own rules without giving its owners access to the global configuration.

## Time-based pruning

`ttlSecondsAfterFinished` sets how many seconds a run may stay after it finished. When a run ends, the Pruner writes the TTL into the annotation `pruner.tekton.dev/ttlSecondsAfterFinished` on the run, and deletes the run once that time has passed after its completion time. The TTL applies to successful and failed runs alike.

The TTL and the history limits work independently. If you set both, a run is deleted when either rule says so: the TTL deletes old runs even when fewer than the limit remain. If you want to delete purely by age, set only the TTL.

## Give each namespace its own rules

The key `enforcedConfigLevel` in `global-config` decides who sets the rules:

| Value | Meaning |
| --- | --- |
| `global` | Only the global configuration counts. Namespace ConfigMaps are ignored (the shipped default) |
| `namespace` | A namespace may set its own rules. Its settings win over the global ones; what it leaves out comes from the global configuration |

Namespace rules live in a ConfigMap that the namespace owner creates in their own namespace. It must be named `tekton-pruner-namespace-spec`, its settings go under the key `ns-config`, and it carries the labels `app.kubernetes.io/part-of: tekton-pruner` and `pruner.tekton.dev/config-type: namespace`. The global configuration can also list namespaces inline under `namespaces:`, but a namespace ConfigMap lets the team manage its own rules.

First allow namespace rules. Change `enforcedConfigLevel` to `namespace` in `tektonconfig-config.yaml` and apply it:

<!-- astrona:playground:renew -->

```sh
kubectl apply -f tektonconfig-config.yaml
kubectl get configmap tekton-pruner-default-spec -n tekton-pipelines -o jsonpath='{.data.global-config}{"\n"}'
```

The second command shows `enforcedConfigLevel: namespace` once the Operator has written it. Now give `starfleet` a 60-second TTL. Save this as `configmap-pruner-starfleet.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tekton-pruner-namespace-spec
  namespace: starfleet
  labels:
    app.kubernetes.io/part-of: tekton-pruner
    pruner.tekton.dev/config-type: namespace
data:
  ns-config: |
    ttlSecondsAfterFinished: 60
```

Apply it:

```sh
kubectl apply -f configmap-pruner-starfleet.yaml
```

Then start a run and watch it:

```sh
tkn task start nightly-check -n starfleet --use-param-defaults --showlog
kubectl get taskruns -n starfleet -o custom-columns='NAME:.metadata.name,TTL:.metadata.annotations.pruner\.tekton\.dev/ttlSecondsAfterFinished,FINISHED:.status.completionTime'
```

The new run carries the TTL `60`. Run the second command again after a minute: the run is gone. The older runs may still be there, because the Pruner has not looked at them since the change. It reads every run again when it starts, so a restart of the Pruner controller applies the TTL to them too.

## The Pruner webhook guards the rules

The Pruner webhook is a validating admission webhook for every ConfigMap with the two Pruner labels. It checks the YAML, the name (`tekton-pruner-default-spec` for the global ConfigMap, `tekton-pruner-namespace-spec` for a namespace), the namespace (never `kube-*` or the Tekton namespaces), and the limits. A namespace may not go above the global values, and where the global configuration sets no limit, the webhook enforces system maximums: 2,592,000 seconds (30 days) for the TTL and 100 for each history limit. Try one that is too big. Save this as `configmap-pruner-starfleet-too-big.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tekton-pruner-namespace-spec
  namespace: starfleet
  labels:
    app.kubernetes.io/part-of: tekton-pruner
    pruner.tekton.dev/config-type: namespace
data:
  ns-config: |
    ttlSecondsAfterFinished: 60
    successfulHistoryLimit: 500
```

Apply it:

```sh
kubectl apply -f configmap-pruner-starfleet-too-big.yaml
```

The API server refuses it with the webhook's message about the history limit. The webhook has `failurePolicy: Fail`, so this protection has a price: if the webhook pod is down, every change to a labelled Pruner ConfigMap is refused until it runs again.

You can now delete runs by age, let namespaces set their own rules, and read why the webhook refuses a configuration. Together with history limits, that covers every rule the Pruner offers, apart from selector groups that match runs by label or annotation inside one namespace ConfigMap.

## Common pitfalls

> [!WARNING]
> - **A namespace ConfigMap under `enforcedConfigLevel: global`.** The Pruner ignores it. Set `namespace` in the global configuration first.
> - **The wrong name.** The Pruner reads only `tekton-pruner-namespace-spec`. Any other name is ignored without an error.
> - **Missing labels.** Without both labels, the webhook does not check the ConfigMap, so a mistake goes unnoticed.
> - **A TTL in the global configuration.** It reaches every namespace that does not set its own.
> - **Expecting old runs to follow a new rule at once.** Restart the Pruner controller, or wait until those runs change.

## Your mission: Configure Time-Based And History-Based Pruning

You can now set history limits and TTLs, and give each namespace its own rules. The graded lab gives you a cluster with the standalone Pruner v0.4.4 in its shipped state, and asks you to delete one team's runs after a minute while another team keeps a fixed number of runs.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-129-playground-020-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-020/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-129-lab-020-01
astrona start ats-129-playground-020-01
```
