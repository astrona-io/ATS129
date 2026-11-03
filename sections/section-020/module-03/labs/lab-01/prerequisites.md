# Prerequisites

Before starting this lab you should be able to:

- Read the status of a `TektonConfig` and the component resources the Tekton Operator creates from it.
- Name the profiles `lite`, `basic` and `all` and the components each installs.
- Edit a custom resource with `kubectl apply` or `kubectl edit`.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **The Tekton Operator v0.81.2** in `tekton-operator`.
- A `TektonConfig` named `config` with the profile `lite`, the target namespace `tekton-pipelines` and `pipeline.enable-api-fields: beta`. The Operator has installed **Tekton Pipelines v1.15.3** from it, and the `TektonConfig` is `Ready`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH.
- A namespace `starfleet` with the service account `triggers-sa`.

## Working rules

- Everything is graded on the **final cluster state**: the `TektonConfig`, the Triggers ConfigMaps the Operator writes, and the health of the installation.
- The Operator needs a few minutes to install Triggers and write the ConfigMaps. The grader waits for it.
