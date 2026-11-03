# Configure Tekton Components Through TektonConfig

An installation that the Tekton Operator manages has one place for settings, the `TektonConfig`, and one rule: whatever the Operator writes, the Operator owns. That rule is simple to say and easy to break. A team edits a ConfigMap to turn on debug logs, the change works for a few minutes, and then the Operator writes the old value back. This module explains where each setting belongs so that a change stays.

The `TektonConfig` is a custom resource named `config`. Its `spec` chooses a profile, which decides the set of components, and it holds a block per component, such as `spec.pipeline`. For each component the Operator creates a second resource, such as `TektonPipeline`, which carries the settings down, and it writes the ConfigMaps and Deployments that the component reads. The Operator keeps all three in line with the `TektonConfig`.

Keep one sentence in mind: **edit the TektonConfig, read the ConfigMaps.** The ConfigMaps in `tekton-pipelines` show what Tekton really uses, and the `TektonConfig` shows what you asked for. If the two differ, the Operator has not reconciled yet or the status shows why.

The module has four parts. **Choose Profiles And Components** switches the profile and reads the component resources. **Set Pipelines Behaviour With spec.pipeline** writes feature flags and defaults. **Reach Any ConfigMap And Deployment With Options** sets keys the `spec.pipeline` block has no field for, and changes Deployments. **Read The Status And Fix A Stuck Installation** follows conditions and installer sets to the cause of a stuck install. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Name what the profiles `lite`, `basic` and `all` install, and prove it from the component resources in the cluster.
- Change the profile and follow the Operator while it adds components.
- Set Tekton Pipelines feature flags and defaults through `spec.pipeline`, and find the ConfigMap that receives each one.
- Use `spec.pipeline.options` to set a ConfigMap key or a Deployment field that has no `spec.pipeline` field.
- Place pods with `spec.config`.
- Read the `Ready` condition, the component resources and the `TektonInstallerSet` objects to find why an installation does not become ready.

## Before you start

You need Kubernetes basics: custom resources, ConfigMaps and Deployments. You should know that the Tekton Operator is a controller that installs Tekton components from custom resources, and that Tekton Pipelines reads its settings from ConfigMaps in `tekton-pipelines`.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-operator` | The Tekton Operator v0.81.2: `tekton-operator` and `tekton-operator-webhook` |
| `TektonConfig` named `config` | Profile `lite`, target namespace `tekton-pipelines`, `enable-api-fields: beta`. It is `Ready` |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.15.3, installed by the Operator |
| Namespace `starfleet` | Empty. Your Tasks and TaskRuns go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

The Operator v0.81.2 installs fixed component versions. The fields in this module work the same in the versions it ships.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
