# Solution: Repair Run Cleanup

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the Pruner webhook runs and admits changes; the global configuration allows namespace settings and `starfleet` has a correct `tekton-pruner-namespace-spec`; a new run in `starfleet` is deleted about 60 seconds after it ends; and a new run in `outpost` gets no TTL.

## Step 1: Reproduce the refusal

Try a harmless change to the global ConfigMap with a server-side dry run:

```sh
kubectl label configmap tekton-pruner-default-spec -n tekton-pipelines check=1 --dry-run=server
```

The API server refuses it: calling the webhook `validation.webhook.pruner.tekton.dev.global` failed because the Service `tekton-pruner-webhook` has no endpoints. Look at the Deployments:

```sh
kubectl get deployments -n tekton-pipelines
kubectl get validatingwebhookconfiguration validation.webhook.pruner.tekton.dev -o jsonpath='{range .webhooks[*]}{.name}{" "}{.failurePolicy}{"\n"}{end}'
```

`tekton-pruner-webhook` shows `0/0`. Both webhooks have `failurePolicy: Fail`, so while nothing answers, the API server refuses every create, update and delete of a ConfigMap that carries the Pruner labels.

## Step 2: Bring the webhook back

```sh
kubectl scale deployment tekton-pruner-webhook -n tekton-pipelines --replicas=1
kubectl rollout status deployment/tekton-pruner-webhook -n tekton-pipelines
kubectl label configmap tekton-pruner-default-spec -n tekton-pipelines check=1 --dry-run=server
```

The dry run now succeeds. If it still fails, the webhook is a few seconds from ready; run it again.

## Step 3: Find why the starfleet settings are ignored

```sh
kubectl get configmap tekton-pruner-default-spec -n tekton-pipelines -o jsonpath='{.data.global-config}{"\n"}'
kubectl get configmaps -n starfleet --show-labels
```

There are two reasons. The global configuration says `enforcedConfigLevel: global`, so the Pruner ignores every namespace ConfigMap. And the `starfleet` settings live in `tekton-pruner-namespace-config`; the Pruner reads only a ConfigMap named `tekton-pruner-namespace-spec`. That ConfigMap also lacks the label `pruner.tekton.dev/config-type: namespace`, so the webhook never checked it.

## Step 4: Allow namespace settings

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

## Step 5: Move the settings to the right ConfigMap

Save this as `configmap-pruner-starfleet.yaml`:

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

Apply it, and remove the old one:

```sh
kubectl apply -f configmap-pruner-starfleet.yaml
kubectl delete configmap tekton-pruner-namespace-config -n starfleet
```

The webhook validated the new ConfigMap on its way in. The old runs finished before the fix, so the Pruner does not look at them again until it restarts; `kubectl rollout restart deployment/tekton-pruner-controller -n tekton-pipelines` makes it read them and delete the expired ones.

## Step 6: Check the result

```sh
tkn task start nightly-check -n starfleet --use-param-defaults
tkn task start nightly-check -n outpost --use-param-defaults
kubectl get taskruns -n starfleet -o custom-columns='NAME:.metadata.name,TTL:.metadata.annotations.pruner\.tekton\.dev/ttlSecondsAfterFinished'
kubectl get taskruns -n outpost -o custom-columns='NAME:.metadata.name,TTL:.metadata.annotations.pruner\.tekton\.dev/ttlSecondsAfterFinished'
```

The new run in `starfleet` shows the TTL `60` and disappears about a minute after it ends. The run in `outpost` has no TTL and stays.

## Step 7: Submit

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Delete the ValidatingWebhookConfiguration to get the change in | Nothing validates the Pruner ConfigMaps any more; the task forbids it |
| Put `ttlSecondsAfterFinished: 60` in the global configuration | `outpost` loses its runs too, and the grader rejects it |
| Rename only, but keep `enforcedConfigLevel: global` | The Pruner still ignores every namespace ConfigMap |
| Add `enforcedConfigLevel: namespace` but keep the wrong name | The Pruner never reads `tekton-pruner-namespace-config` |
| Delete the old runs by hand | New runs still pile up |

## Common mistakes

- Waiting for the dry run to pass right after the scale. The webhook needs a few seconds to serve.
- Adding labels to the wrongly named ConfigMap. The webhook then refuses it, because a namespace configuration must be named `tekton-pruner-namespace-spec`.
- Expecting old runs to vanish at once. A restart of the Pruner controller makes it read them again.

## Practice on your own

- Scale the webhook to zero again and try to create a ConfigMap without the Pruner labels. Which requests does the webhook block?
- Give `starfleet` a `failedHistoryLimit` and find out whether the TTL or the limit removes a failed run first.
- Read the controller log for the run it deleted: `kubectl logs -n tekton-pipelines deploy/tekton-pruner-controller`.
