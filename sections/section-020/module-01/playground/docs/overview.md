# Overview: Manage Tekton With The Operator And The Pruner (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with the Tekton Operator and nothing else from Tekton: you install Tekton through the Operator yourself. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **The Tekton Operator v0.81.2** in the namespace `tekton-operator`. The Tekton Operator is a Kubernetes operator: a controller that installs, configures and upgrades the Tekton components from custom resources. Its Deployments are `tekton-operator` and `tekton-operator-webhook`.
- No `TektonConfig` yet. The release manifest normally creates one with the profile `all` as soon as the Operator starts; the playground switched that off (`AUTOINSTALL_COMPONENTS: "false"` in the ConfigMap `tekton-config-defaults`).
- The `tkn` command-line tool, version **0.46.2**, and an empty namespace `starfleet`.
- The image `busybox:1.37.0`, already loaded on the node.

Operator v0.81.2 installs fixed versions of each component: Tekton Pipelines **v1.15.3** and the Tekton Pruner **v0.4.3**, among others. The fields used in this module work the same in those versions.

## Helpers

Paste these once in each new terminal. `show_tekton` prints the state of the `TektonConfig` and of the components the Operator manages. `count_runs` counts the TaskRuns in `starfleet` by status. `run_hello` starts the Task `hello` once (create the Task first).

```sh
show_tekton() {
  kubectl get tektonconfig,tektonpipelines,tektonpruners 2>/dev/null
}
count_runs() {
  kubectl get taskruns -n starfleet -o jsonpath='{range .items[*]}{.status.conditions[0].status}{"\n"}{end}' | sort | uniq -c
}
run_hello() {
  tkn task start hello -n starfleet --use-param-defaults
}
```

## Practice tasks

- Create a `TektonConfig` with the profile `lite`, then change it to `basic`, and list which components the Operator adds with `kubectl get tektoninstallersets`.
- Change `spec.pipeline.enable-api-fields` in the `TektonConfig` and read the ConfigMap `feature-flags` in `tekton-pipelines`. Then edit `feature-flags` by hand and watch whether the Operator puts its own value back.
- Enable the event-based pruner with only `historyLimit: 2`, run the `hello` Task five times and run `count_runs`.
- Give `starfleet` a namespace ConfigMap with `ttlSecondsAfterFinished: 30` and try to set the same value while `enforcedConfigLevel` is `global`. What changes?
- Try a namespace ConfigMap with `successfulHistoryLimit: 500` and read the Pruner webhook's answer.
