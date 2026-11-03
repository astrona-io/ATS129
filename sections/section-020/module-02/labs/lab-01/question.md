# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Operations

## Scenario

The `starfleet` team's pipelines run on a Tekton installation that the Tekton Operator manages. Builds sometimes hang, and the default timeout of one hour is too long for the team. The team also wants the stable API only, and it needs debug logs from the Pipelines controller while it looks for the cause. A colleague already tried to edit the ConfigMaps by hand, and the Operator undid the changes.

## Your task

Change the existing `TektonConfig` named `config` so that the Operator writes these settings into the Pipelines ConfigMaps:

1. `enable-api-fields` is `stable`.
2. `default-timeout-minutes` is `30`.
3. The Pipelines controller logs at the level `debug`: the key `loglevel.controller` in the ConfigMap `config-logging` is `debug`.

## Constraints

- Keep the `TektonConfig` named `config`, with the profile `lite` and the target namespace `tekton-pipelines`.
- Change only the `TektonConfig`. Do not edit the ConfigMaps in `tekton-pipelines` by hand.
- Do not install or remove any component.

## Done when

- The `TektonConfig` holds the three settings above, and it keeps its profile and target namespace.
- The ConfigMaps `feature-flags`, `config-defaults` and `config-logging` in `tekton-pipelines` hold the values `stable`, `30` and `debug`.
- The `TektonConfig` is `Ready` and the Deployment `tekton-pipelines-controller` is available.
