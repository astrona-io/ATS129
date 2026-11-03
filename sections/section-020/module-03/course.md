# Add Triggers And Plan An Operator Upgrade

The Tekton Operator does two jobs over the life of an installation. It installs and configures components from one object, the `TektonConfig`, and it moves the whole installation to a new version when you give it a new release. This module covers one change of each kind: adding Tekton Triggers to a Pipelines-only installation, and planning an Operator upgrade so that nothing breaks.

Keep one sentence in mind: **the TektonConfig is the only place you change a component, and the Operator version decides which component versions you get.** A change made by hand in a ConfigMap or Deployment is put back at the next reconcile, and a new Operator release replaces the component versions at once.

The module has four parts. **Add Triggers With The Profile** switches a `lite` installation to `basic` and shows what appears. **Configure Triggers Through spec.trigger** sets the Triggers properties and finds the ConfigMaps they end up in. A graded lab follows that part. **Plan An Operator Upgrade** covers release notes, the order of steps and what to save first. **Verify An Upgrade And Recover** reads versions and conditions after the change and describes what to do when it fails.

## Learning objectives

After this module you can:

- Name the components that the profiles `lite`, `basic` and `all` install, and add Tekton Triggers by changing the profile.
- Set `spec.trigger.default-service-account` and `spec.trigger.enable-api-fields`, and find the ConfigMaps that carry them.
- Explain why a hand edit of an Operator-managed ConfigMap does not stay.
- Plan an Operator upgrade: read the release notes, save the `TektonConfig`, upgrade one release at a time and keep a way back.
- Check the result of an upgrade with the versions and the Ready conditions of the Operator resources.

## Before you start

You need to know what the Tekton Operator and a `TektonConfig` are. In short: the Operator is a controller that installs Tekton components from custom resources, and the `TektonConfig` named `config` holds the profile and the settings for every component it installs.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-operator` | Tekton Operator v0.81.2 |
| `TektonConfig` `config` | Profile `lite`, target namespace `tekton-pipelines`, Tekton Pipelines v1.15.3 installed and Ready |
| Namespace `starfleet` | Empty. Your Tasks and TaskRuns go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
