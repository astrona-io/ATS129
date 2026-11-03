# Verify An Upgrade And Recover

After the new release is applied, the Operator needs time to roll every component. This part shows what to read to know the upgrade is done, and what to do when it is stuck.

## Wait for the Operator, then the TektonConfig

The Operator Deployment rolls first:

<!-- astrona:playground:renew -->

```sh
kubectl -n tekton-operator rollout status deployment/tekton-operator --timeout=300s
kubectl -n tekton-operator rollout status deployment/tekton-operator-webhook --timeout=300s
```

Then the `TektonConfig` must become Ready again:

```sh
kubectl wait tektonconfig/config --for=condition=Ready --timeout=900s
kubectl get tektonconfig,tektonpipelines
```

The resource listings show the version of each component. Compare them with the numbers you wrote down before.

## Read the conditions of a stuck component

When the `TektonConfig` stays not Ready, the message points at the component. Read the conditions of the config and then of the component named in the message:

```sh
kubectl get tektonconfig config -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" "}{.message}{"\n"}{end}'
kubectl get tektonpipelines.operator.tekton.dev pipeline -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" "}{.message}{"\n"}{end}'
```

Common causes are an image that cannot be pulled, a field in the `TektonConfig` that the new version rejects, and a webhook that is not ready. The Operator log shows the reconcile errors:

```sh
kubectl -n tekton-operator logs deployment/tekton-operator --tail=30
```

## Check the installer sets

The Operator installs each component through installer sets, which hold the rendered manifests. After an upgrade the sets are replaced:

```sh
kubectl get tektoninstallersets
```

Sets that stay not Ready, or old sets that are never removed, point at a failed step. Name the set that has the problem in your notes, and read its conditions with `kubectl get tektoninstallerset <name> -o yaml`.

## Prove Tekton works

A Ready status does not prove that runs work. Start a small run and read the result:

```sh
kubectl -n starfleet get taskruns
```

Apply a small Task in `starfleet`, start it with `tkn task start`, and confirm that the TaskRun succeeds. For Triggers, send a test event to one EventListener and confirm that a run starts.

## When the upgrade fails

- If a field was rejected, fix it in the `TektonConfig` from your backup and apply it; the Operator reconciles again.
- If a component is stuck on an image or a webhook, read the pod events in the target namespace first.
- Downgrading by applying an older release is not a safe way back, because newer releases may have changed stored objects and CRDs. Plan the way back as a restore of the cluster state or a rebuild from the saved `TektonConfig` and the definitions in version control.

## What to remember

- Wait for the Operator Deployments, then for the `TektonConfig` to be Ready.
- The conditions name the component that blocks; the Operator log gives the reason.
- Installer sets show which rendered manifests are in place.
- Test a real run after the upgrade; plan the way back before you start.
