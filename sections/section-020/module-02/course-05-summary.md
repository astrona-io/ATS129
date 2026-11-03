# Summary

The Tekton Operator manages Tekton from one resource, the `TektonConfig` named `config`. A rule governs the whole module: edit the `TektonConfig`, and read the ConfigMaps to see what Tekton really uses. The Operator writes its own values back into every resource it manages, so a hand edit does not last.

The field `spec.profile` chooses the components: `lite` installs Tekton Pipelines, `basic` adds Triggers and Chains, and `all` adds the Dashboard. For each component the Operator creates a resource with a fixed name, such as `TektonPipeline` named `pipeline`, and removing a component means changing the profile. Settings of Pipelines live in `spec.pipeline`, where the field name is the ConfigMap key name. `enable-api-fields` belongs to `feature-flags`, and `default-timeout-minutes` belongs to `config-defaults`. Keys with no field go under `spec.pipeline.options.configMaps.<name>.data`, and Deployment changes go under `options.deployments.<name>.spec`. Settings for the pods of all components go under `spec.config`.

A stuck installation is read in a fixed order: the conditions of the `TektonConfig`, the component resource, the `TektonInstallerSet` objects, and then the pods and the Operator logs. The key facts to remember are these:

- Keep `profile` and `targetNamespace` in every file you apply.
- A value reaches a ConfigMap after the `TektonConfig` is `Ready`; read the ConfigMap to prove it.
- An unknown key in `options` is written and ignored, so check the key name.
- Never edit or delete installer sets, and save the `TektonConfig` before an Operator upgrade.

<!-- astrona:playground:destroy -->
