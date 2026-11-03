# Read The Status And Fix A Stuck Installation

When a change does not arrive, the cause is almost always visible in the status of one resource. This part gives a fixed order for reading it: the `TektonConfig`, the component resource, the installer set, and the Operator logs. You will follow the order on a healthy cluster first, so that you know what normal looks like.

## Level 1: the TektonConfig

```sh
kubectl get tektonconfig config
kubectl get tektonconfig config -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" "}{.reason}{" "}{.message}{"\n"}{end}'
```

The first command shows the `READY` column and a `REASON`. The second prints every condition. The condition `Ready` is the one to read. When it is `False`, the message names the component or the step that waits. If `Ready` is `True` and the ConfigMap still holds an old value, the change did not reach the `TektonConfig`, so read the spec again.

## Level 2: the component resource

Each component has its own resource with the same condition shape:

```sh
kubectl get tektonpipeline pipeline
kubectl get tektonpipeline pipeline -o jsonpath='{.status.version}{"\n"}'
```

The status holds the installed version, which tells you which Pipelines release the Operator installed. In the playground that is v1.15.3, because the Operator v0.81.2 ships that release. A component stuck at `False` points at its own Deployments or at its installer sets.

## Level 3: the installer sets

The Operator does not apply the release manifest itself. It stores the parts of it in `TektonInstallerSet` objects and applies those:

```sh
kubectl get tektoninstallerset
kubectl describe tektoninstallerset | grep -E '^Name:|Type|Message'
```

There is one installer set per kind of resource group, for example one for the CRDs, one for the cluster-scoped objects and one for the Deployments. Each carries its own `Ready` condition. A failed installer set names the object that did not apply, such as a CRD that the API server rejected.

> [!IMPORTANT]
> Do not edit or delete an installer set. The Operator owns it and rebuilds it from the component resource.

## Level 4: the workloads and the Operator logs

```sh
kubectl get pods -n tekton-pipelines
kubectl describe pod -n tekton-pipelines -l app=tekton-pipelines-controller | tail -20
kubectl logs deploy/tekton-operator -n tekton-operator --tail=30
```

A pod in `ImagePullBackOff` or `Pending` is the usual cause when everything above waits. The Operator log shows each reconcile and the error it hit.

## Frequent causes

| What you see | Likely cause | What to do |
| --- | --- | --- |
| `Ready=False`, message about waiting for a Deployment | Image pull or scheduling problem | Describe the pod and fix the node or the image access |
| ConfigMap keeps the old value | The key is not in the spec, or the apply went to another object | Read `kubectl get tektonconfig config -o yaml` and compare |
| Unknown key accepted but no effect | Wrong key name in `options` | Check the name in the component's ConfigMap |
| A webhook error when you apply the TektonConfig | The Operator webhook pod is not ready | Wait for `tekton-operator-webhook` or read its logs |
| Component missing after a profile change | The profile does not list it | Check the profile table and the component resources |

## Upgrades

The Operator release decides the Tekton versions. Upgrading the Operator to a newer release makes it upgrade the components to the versions that release ships, and the component resources report the new `status.version` when it is done. Take a copy of the `TektonConfig` before an upgrade with `kubectl get tektonconfig config -o yaml`, and read the Operator release notes, because fields can be added or deprecated between releases.

Updating by changing the Operator is the only supported way to move the Tekton versions, so apply the Operator release manifest of the target version and let the Operator do the rest.

## Walk through a real check

Run the full order once on the healthy playground, and write down what each level prints. Then you know the normal output, and a difference stands out when a real problem appears. The commands are the ones above, in the same order.

## Common pitfalls

> [!WARNING]
> - **Starting at the pods.** Start at the `TektonConfig` condition, which usually names the cause.
> - **Deleting an installer set to force a retry.** The Operator owns it. Fix the cause instead.
> - **Upgrading without a copy of the spec.** Save the YAML first.
> - **Reading the logs of the wrong namespace.** The Operator runs in `tekton-operator`, the components in `tekton-pipelines`.
