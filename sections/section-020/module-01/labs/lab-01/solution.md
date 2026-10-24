# Solution: Configure Time-Based And History-Based Pruning

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the global configuration allows namespace settings and keeps `historyLimit: 100`; the two namespace ConfigMaps have the right name, labels and values; a new run in `starfleet` is deleted about 60 seconds after it ends; and `outpost` keeps only its 3 newest successful and 2 newest failed runs.

## Step 1: Read the shipped configuration

```sh
kubectl get configmap tekton-pruner-default-spec -n tekton-pipelines -o yaml
kubectl get pods -n tekton-pipelines -l app=tekton-pruner-controller
```

The ConfigMap has the labels `app.kubernetes.io/part-of: tekton-pruner` and `pruner.tekton.dev/config-type: global`, and its key `global-config` holds `enforcedConfigLevel: global` and `historyLimit: 100`. With `global`, the Pruner ignores every namespace ConfigMap, so step 1 of the task comes first.

## Step 2: Allow namespace settings

Save this as `configmap-tekton-pruner-default-spec.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tekton-pruner-default-spec
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/part-of: tekton-pruner
    pruner.tekton.dev/config-type: global
data:
  global-config: |
    enforcedConfigLevel: namespace
    historyLimit: 100
```

Apply it:

```sh
kubectl apply -f configmap-tekton-pruner-default-spec.yaml
```

The Pruner webhook validates the ConfigMap first; a typing error in `global-config` makes `kubectl apply` fail with the webhook's message.

## Step 3: A 60-second TTL for starfleet

The namespace ConfigMap must be called `tekton-pruner-namespace-spec`, and its settings go under the key `ns-config`. Save this as `configmap-pruner-starfleet.yaml`:

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

## Step 4: History limits for outpost

Save this as `configmap-pruner-outpost.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tekton-pruner-namespace-spec
  namespace: outpost
  labels:
    app.kubernetes.io/part-of: tekton-pruner
    pruner.tekton.dev/config-type: namespace
data:
  ns-config: |
    successfulHistoryLimit: 3
    failedHistoryLimit: 2
```

Apply it:

```sh
kubectl apply -f configmap-pruner-outpost.yaml
```

## Step 5: Apply the rules to the old runs too

The Pruner acts on events: it checks a run when the run changes, for example when it finishes. The six runs from before your change already finished, so the Pruner does not look at them again by itself. Restart the controller; on start it reads every run once more:

```sh
kubectl rollout restart deployment/tekton-pruner-controller -n tekton-pipelines
kubectl rollout status deployment/tekton-pruner-controller -n tekton-pipelines
```

## Step 6: Watch it work

Start one run in each namespace, then list the runs twice, a minute apart:

```sh
tkn task start nightly-check -n starfleet --use-param-defaults
tkn task start nightly-check -n outpost --use-param-defaults
kubectl get taskruns -n starfleet -o custom-columns='NAME:.metadata.name,TTL:.metadata.annotations.pruner\.tekton\.dev/ttlSecondsAfterFinished'
kubectl get taskruns -n outpost
```

In `starfleet`, each finished run carries the annotation `pruner.tekton.dev/ttlSecondsAfterFinished` with the value `60` and disappears about a minute after it ended. In `outpost`, runs have no TTL, and only the 3 newest successful and the 2 newest failed runs stay.

## Step 7: Submit

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Create the namespace ConfigMaps but keep `enforcedConfigLevel: global` | The Pruner ignores them; nothing changes |
| Put `ttlSecondsAfterFinished: 60` into the global configuration | Every namespace, `outpost` too, loses its runs after a minute |
| Name the ConfigMap differently, for example `pruner-config` | The Pruner only reads `tekton-pruner-namespace-spec` |
| Leave out the labels | The webhook does not validate the ConfigMap, so a mistake stays hidden; the grader requires both labels |
| Delete the old runs with `kubectl delete` | The new runs still pile up; the grader checks what the Pruner does with new runs |

## Common mistakes

- Using `historyLimit: 3` in `outpost`. It keeps 3 runs of each status, so 3 failed runs stay instead of 2.
- Adding a TTL and history limits together and expecting the limits to protect runs. The TTL deletes runs even below the limit.
- Putting the namespace ConfigMap in `tekton-pipelines`. The webhook rejects namespace configuration in the Tekton namespaces.

## Practice on your own

- Add a `taskRuns` group with a `selector` to the `outpost` ConfigMap and give runs with a label a longer history.
- Try to set `successfulHistoryLimit: 150` in a namespace ConfigMap and read the webhook's error.
- Read the Pruner metric `tekton_pruner_controller_resources_deleted_total` with `kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pruner-controller:9090/proxy/metrics`.
