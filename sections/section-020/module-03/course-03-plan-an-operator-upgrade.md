# Plan An Operator Upgrade

The Operator version sets the versions of the components it installs. In the playground, Operator v0.81.2 installs Tekton Pipelines v1.15.3. A newer Operator release installs newer component versions, and applying it upgrades every component at once. That makes an upgrade a bigger step than it looks, so plan it before you apply anything.

## Find the starting point

Read what runs now:

<!-- astrona:playground:renew -->

```sh
kubectl -n tekton-operator get deployment tekton-operator -o jsonpath='{.spec.template.spec.containers[*].image}'; echo
kubectl get tektonconfig,tektonpipelines
kubectl get tektontrigger.operator.tekton.dev 2>/dev/null
```

Write down the Operator image, the component resources and the profile. This is the state you compare with after the upgrade.

## Read the release notes first

Every Operator release lists the component versions it installs, changed or removed fields, and required Kubernetes versions. Look for these before you decide:

- The Pipelines, Triggers and other component versions the new release installs, and the notes of those components.
- API fields that were removed or renamed in `TektonConfig`, so a field you use still exists.
- A minimum Kubernetes version.
- Any note that says you must upgrade through an earlier release.

Move one release at a time when the notes say so, and do not skip several minor versions at once on a cluster that matters.

## Save what you can restore

The Operator rebuilds components from the `TektonConfig`, so that object is the most valuable one. Save it, and the Tekton data you would miss:

```sh
kubectl get tektonconfig config -o yaml > tektonconfig-backup.yaml
kubectl get pipelines.tekton.dev,tasks.tekton.dev -A -o yaml > tekton-definitions-backup.yaml
```

Pipelines and Tasks are stored in the cluster, not in the Operator, so a cluster backup that includes etcd or your GitOps repository is the real safety net. Runs are also objects; decide whether you need to keep them.

## Pick a time and a test

Running TaskRuns keep going while components restart, but controllers are briefly unavailable, so new runs are delayed. Choose a time with no critical pipeline, and test the upgrade first on a cluster that has the same profile and the same `TektonConfig` fields as production.

## The upgrade step itself

The upgrade is to apply the release manifest of the new Operator version. The command has this shape; the version is a placeholder, not a recommendation:

```sh
kubectl apply -f https://infra.tekton.dev/tekton-releases/operator/previous/<version>/release.yaml
```

The Operator Deployment is replaced, and the new Operator reconciles the `TektonConfig` against the new component versions. Do not run this in the playground: it would move the Operator away from the version that the pages and the lab expect.

## What the release manifest sets

The release manifest sets `AUTOINSTALL_COMPONENTS` to `"true"`, which makes a new Operator create a `TektonConfig` with the profile `all` when none exists. An installation that has a `TektonConfig` is not replaced, but an installation where someone deleted it would suddenly gain every component. Keep the `TektonConfig` in version control, and check the setting in the ConfigMap `tekton-config-defaults` in `tekton-operator`.

## What to remember

- The Operator version decides the component versions.
- Read the release notes for removed fields and for the order of upgrades.
- Save the `TektonConfig` and keep Tekton definitions in version control.
- Applying the release manifest is the upgrade; test it elsewhere first.
