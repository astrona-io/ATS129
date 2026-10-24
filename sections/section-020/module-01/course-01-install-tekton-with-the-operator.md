# Install And Configure Tekton With The Operator

A cluster that runs Tekton Pipelines, Triggers, Chains and the Dashboard from release manifests has four install commands, four upgrade procedures and settings spread over many ConfigMaps. Nothing stops two administrators from changing the same ConfigMap in different ways. The Tekton Operator replaces all of that with one custom resource and one controller that keeps the installation as described. This part installs Tekton through the Operator and shows how it reports, changes and upgrades the installation.

## What the Operator installs

The Operator itself comes from a release manifest. In the playground it is already applied, with one change: the release normally creates a `TektonConfig` with the profile `all` as soon as the Operator starts, and the playground switched that off in the ConfigMap `tekton-config-defaults` (`AUTOINSTALL_COMPONENTS: "false"`), so you can create it yourself. Check the Operator and the resource kinds it adds:

<!-- astrona:playground:renew -->

```sh
kubectl get pods -n tekton-operator
kubectl api-resources --api-group=operator.tekton.dev
```

Two pods run: `tekton-operator` and `tekton-operator-webhook`. The API group `operator.tekton.dev` has one kind per component (`TektonPipeline`, `TektonTrigger`, `TektonChain`, `TektonDashboard`, `TektonResult`, `TektonPruner` and more), plus two kinds that tie them together:

| Kind | What it is |
| --- | --- |
| `TektonConfig` | The one resource you edit, always named `config`. It names the profile, the target namespace and the settings of every component |
| `TektonPipeline`, `TektonPruner`, ... | One resource per installed component. The Operator creates them from the `TektonConfig` |
| `TektonInstallerSet` | A set of plain Kubernetes objects (Deployments, ConfigMaps, CRDs) that the Operator applied for one component. It is how the Operator tracks what it owns |

The profile decides which components the Operator installs: `lite` installs Tekton Pipelines; `basic` adds Triggers and Chains (and Results); `all` adds the Dashboard on Kubernetes.

## Install Tekton with a TektonConfig

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
```

Apply it:

```sh
kubectl apply -f tektonconfig-config.yaml
```

Then check the result. The Operator needs a few minutes to pull the images and start the components:

```sh
kubectl wait tektonconfig/config --for=condition=Ready --timeout=600s
kubectl get tektonconfig,tektonpipelines
kubectl get pods -n tekton-pipelines
```

`kubectl get tektonconfig` shows the columns `VERSION`, `READY` and `REASON`, taken from the `Ready` condition. When `READY` is `True`, the `VERSION` column shows the Operator version, and the `TektonPipeline` named `pipeline` shows `v1.15.3`: the Pipelines version that Operator v0.81.2 ships. The namespace `tekton-pipelines` now holds the same Deployments as an installation from the release manifest, such as `tekton-pipelines-controller` and `tekton-pipelines-webhook`. While a component is still starting, `REASON` holds the message that says which one the Operator waits for.

Look at what the Operator applied for each component:

```sh
kubectl get tektoninstallersets
```

Each installer set has a name that starts with the component, for example `pipeline-main-deployment-` and `pipeline-main-static-` followed by a random suffix. If someone deletes an object from an installer set, the Operator creates it again.

## Change a setting through the TektonConfig

With the Operator, every setting has one home: the `TektonConfig`. The `spec.pipeline` block holds the keys of the Pipelines ConfigMaps `feature-flags` and `config-defaults`, such as `enable-api-fields`. Change `enable-api-fields` from `beta` to `alpha` in `tektonconfig-config.yaml`, then apply it again:

```sh
kubectl apply -f tektonconfig-config.yaml
```

Then check the result in the ConfigMap that Tekton Pipelines reads:

```sh
kubectl get configmap feature-flags -n tekton-pipelines -o jsonpath='{.data.enable-api-fields}{"\n"}'
```

It prints `alpha` once the Operator has reconciled the change. Change it back to `beta` and apply the file once more. Do not edit `feature-flags` by hand: the Operator owns it and puts the value from the `TektonConfig` back when it reconciles.

## How an upgrade works

Every Operator release ships a fixed set of component versions. Operator v0.81.2, for example, ships Tekton Pipelines v1.15.3, Triggers v0.37.1, Chains v0.29.7, the Dashboard v0.71.0 and the Pruner v0.4.3. You do not choose a Pipelines version in the `TektonConfig`; you choose an Operator version.

To upgrade, you apply the release manifest of the newer Operator: `kubectl apply -f https://infra.tekton.dev/tekton-releases/operator/previous/<version>/release.yaml`. The new Operator pod starts, compares the installed components with the versions it ships, and replaces the installer sets one component at a time. Your `TektonConfig` stays as it is, so every setting survives the upgrade. You follow the upgrade with `kubectl get tektonconfig` until `VERSION` shows the new release and `READY` is `True` again. Read the release notes first: an Operator release can move several components forward at once, including a new Pipelines LTS line.

You can now install Tekton through the Operator, read its state, change a setting in one place, and explain how an upgrade happens. The cluster still keeps every TaskRun forever. The open question is how to let the Operator install the Pruner and keep only the runs you need.

## Common pitfalls

> [!WARNING]
> - **Editing the ConfigMaps the Operator owns.** Changes to `feature-flags` or `config-defaults` are overwritten. Change the `TektonConfig`.
> - **Naming the `TektonConfig` something other than `config`.** The Operator works with one `TektonConfig` named `config`.
> - **Expecting the profile `all` on a small cluster.** It installs every component, which needs far more memory than `lite`.
> - **Mixing the Operator with release manifests.** Applying a Pipelines `release.yaml` on top of an Operator installation gives two owners for the same objects.
> - **Pinning component versions by hand.** One Operator release pins all component versions; upgrade the Operator instead.
