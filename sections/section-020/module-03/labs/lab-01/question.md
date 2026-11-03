# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Operations

## Scenario

The `starfleet` team runs Tekton through the Tekton Operator with the profile `lite`, which installs Tekton Pipelines only. The team now wants event-driven runs, so Tekton Triggers must be installed and configured. EventListeners in the namespace `starfleet` should run as the service account `triggers-sa` unless they name another, and the team wants the Triggers alpha features for a pilot. The Pipelines setting must not change.

## Your task

Change the `TektonConfig` named `config` so that:

1. The profile is `basic`, which adds Tekton Triggers (and Tekton Chains) to Tekton Pipelines.
2. `spec.trigger.default-service-account` is `triggers-sa`.
3. `spec.trigger.enable-api-fields` is `alpha`.
4. Everything else stays: `targetNamespace: tekton-pipelines` and `spec.pipeline.enable-api-fields: beta`.

## Constraints

- Change Triggers only through the `TektonConfig`. Do not edit the Triggers ConfigMaps or Deployments by hand.
- Do not create a `TektonTrigger` resource yourself.
- The service account `triggers-sa` already exists in `starfleet`.

## Done when

- The `TektonConfig` has the profile `basic` and the two Triggers properties above, and still has the Pipelines setting and the target namespace.
- The ConfigMap `feature-flags-triggers` in `tekton-pipelines` has `enable-api-fields: alpha`, and `config-defaults-triggers` has `default-service-account: triggers-sa`.
- The `TektonConfig` and the `TektonTrigger` are `Ready`, and the Deployments `tekton-triggers-controller` and `tekton-triggers-webhook` are available.
