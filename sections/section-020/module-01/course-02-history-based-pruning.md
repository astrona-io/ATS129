# Keep A Fixed Number Of Runs With History Limits

Tekton never deletes a finished run by itself. Each TaskRun stays in the API server, and with the default settings its pod stays on the node too. A busy cluster collects thousands of them within weeks, and every controller that lists TaskRuns gets slower. History-based pruning keeps the newest few runs and deletes the rest. This part switches on the Tekton Pruner through the Operator and watches it keep a fixed number of runs.

## Two pruners

Tekton has two ways to clean up runs, and the names are easy to mix up:

| Pruner | Where it is set | How it works |
| --- | --- | --- |
| Job-based pruner | `spec.pruner` in the `TektonConfig` (Operator only) | A CronJob that runs `tkn ... delete --keep` on a schedule, such as `0 8 * * *` |
| Event-based Tekton Pruner | `spec.tektonpruner` in the `TektonConfig`, or the standalone release of `tektoncd/pruner` | A controller that reacts the moment a run finishes, with rules in ConfigMaps |

The event-based Tekton Pruner is the newer one, and it is what this module uses. The Operator does not allow both at once: to enable `spec.tektonpruner`, you must set `spec.pruner.disabled: true`. Without the Operator, you install the standalone Pruner from its release manifest (`https://infra.tekton.dev/tekton-releases/pruner/previous/v0.4.4/release.yaml`), which adds the Deployments `tekton-pruner-controller` and `tekton-pruner-webhook` to `tekton-pipelines`.

## Enable the event-based Pruner

The Pruner's rules sit in a block called `global-config`. History-based pruning has three keys, and each counts runs per status:

| Key | Meaning |
| --- | --- |
| `successfulHistoryLimit` | Keep this many of the newest successful runs |
| `failedHistoryLimit` | Keep this many of the newest failed runs |
| `historyLimit` | Keep this many runs of each status, where the two keys above are not set (shipped default: `100`) |

Add the Pruner to the `TektonConfig`, replacing the earlier version of the file.

<!-- astrona:playground:renew -->

Save this as `tektonconfig-config.yaml`:

```yaml
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  name: config
spec:
  profile: lite
  targetNamespace: tekton-pipelines
  pipeline:
    enable-api-fields: beta
  pruner:
    disabled: true
  tektonpruner:
    disabled: false
    global-config:
      enforcedConfigLevel: global
      successfulHistoryLimit: 3
      failedHistoryLimit: 2
```

Apply it:

```sh
kubectl apply -f tektonconfig-config.yaml
```

Then check the result:

```sh
kubectl wait tektonconfig/config --for=condition=Ready --timeout=600s
kubectl get tektonpruners
kubectl get pods -n tekton-pipelines
kubectl get configmap tekton-pruner-default-spec -n tekton-pipelines -o yaml
```

The `TektonPruner` named `pruner` is ready, and `tekton-pipelines` has two new pods: the Pruner controller and the Pruner webhook. The Operator wrote your `global-config` into the ConfigMap `tekton-pruner-default-spec`, which carries the labels `app.kubernetes.io/part-of: tekton-pruner` and `pruner.tekton.dev/config-type: global`. Without the Operator, you edit that ConfigMap directly; with the Operator, you edit the `TektonConfig`.

## Watch the limits work

Create a Task that passes or fails on demand. Save this as `task-nightly-check.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: nightly-check
  namespace: starfleet
spec:
  params:
    - name: outcome
      type: string
      default: pass
  steps:
    - name: check
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        echo "nightly check: $(params.outcome)"
        [ "$(params.outcome)" = "pass" ]
```

Apply it, and run it five times successfully and three times with a failure:

```sh
kubectl apply -f task-nightly-check.yaml
for outcome in pass pass pass pass pass fail fail fail; do
  tkn task start nightly-check -n starfleet -p outcome=$outcome --showlog >/dev/null
done
```

Then check the result:

```sh
kubectl get taskruns -n starfleet --sort-by=.metadata.creationTimestamp
```

Only three successful and two failed runs remain, and they are the newest of each kind. The Pruner acted each time a run finished: it listed the runs of that status in the namespace, sorted them by creation time, and deleted everything after the limit. Each run it checked carries the annotation `pruner.tekton.dev/historyLimitCheckProcessed`, so the Pruner does not check it twice.

That last point matters when you change a limit. The Pruner reacts to events, so a lower limit takes effect the next time a run of that status finishes, not at once.

History limits keep the newest runs no matter how old they are. A team that runs a Task once a month keeps runs from last year; a team that runs it every minute keeps only the last few minutes. The open question is how to delete runs by age instead, and how to give each team its own rules.

## Common pitfalls

> [!WARNING]
> - **Enabling both pruners.** The Operator refuses `spec.tektonpruner` while `spec.pruner` is enabled. Set `spec.pruner.disabled: true`.
> - **Reading `historyLimit` as a total.** It counts per status: `historyLimit: 3` keeps up to 3 successful and 3 failed runs.
> - **Expecting a new limit to clean up at once.** The Pruner acts when the next run of that status finishes.
> - **Editing `tekton-pruner-default-spec` under the Operator.** The Operator writes it from the `TektonConfig`; change the `TektonConfig`.
> - **Counting runs of a PipelineRun.** The Pruner handles TaskRuns of a PipelineRun through the PipelineRun; its rules for TaskRuns apply to standalone runs.
