# Overview: Add Triggers And Plan Upgrades With The Operator (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with the Tekton Operator and a running Tekton Pipelines installation that the Operator manages. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **The Tekton Operator v0.81.2** in the namespace `tekton-operator`. The Tekton Operator is a Kubernetes operator: a controller that installs, configures and upgrades the Tekton components from custom resources. Its Deployments are `tekton-operator` and `tekton-operator-webhook`.
- A `TektonConfig` named `config` with the profile `lite`, `targetNamespace: tekton-pipelines` and `pipeline.enable-api-fields: beta`. The Operator has installed **Tekton Pipelines v1.15.3** from it, and the `TektonConfig` is `Ready`.
- The `tkn` command-line tool, version **0.46.2**, and an empty namespace `starfleet`.
- The image `busybox:1.37.0`, already loaded on the node.

The release manifest normally creates a `TektonConfig` with the profile `all` as soon as the Operator starts; the playground switched that off (`AUTOINSTALL_COMPONENTS: "false"` in the ConfigMap `tekton-config-defaults`) and created the `lite` one itself.

## Helpers

Paste these once in each new terminal. `show_tekton` prints the `TektonConfig` and the component resources the Operator manages. `show_flag` prints one key of a ConfigMap in `tekton-pipelines`.

```sh
show_tekton() {
  kubectl get tektonconfig,tektonpipelines,tektontriggers,tektonchains,tektondashboards 2>/dev/null
}
show_flag() {
  kubectl get configmap "$1" -n tekton-pipelines -o jsonpath="{.data.$2}"; echo
}
```

Use them like this: `show_tekton`, `show_flag feature-flags enable-api-fields`, `show_flag config-defaults default-timeout-minutes`.

## Practice tasks

- Change the profile to `basic`, wait until the `TektonConfig` is `Ready`, and list the Deployments that Tekton Triggers adds in `tekton-pipelines`.
- Set `spec.trigger.default-service-account` and `spec.trigger.enable-api-fields`, then read the ConfigMaps `config-defaults-triggers` and `feature-flags-triggers`.
- Read the version of the Operator image with `kubectl -n tekton-operator get deployment tekton-operator -o jsonpath='{.spec.template.spec.containers[*].image}'` and the version of each component resource with `kubectl get tektonconfig,tektonpipelines,tektontriggers`.
- Save the `TektonConfig` with `kubectl get tektonconfig config -o yaml > tektonconfig-backup.yaml`, delete a ConfigMap that the Operator manages, and watch it come back.
- Read `kubectl get tektoninstallersets` and note which installer sets exist for Pipelines and for Triggers.
