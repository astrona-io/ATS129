# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Operations

## Scenario

The `starfleet` team asked for its finished runs to be deleted one minute after they end, and someone wrote the settings into a ConfigMap in `starfleet`. Weeks later the runs are all still there. When the team tried to change the Pruner configuration, `kubectl apply` refused it with an error about a webhook. The `outpost` team must not be affected: its runs stay under the cluster-wide default.

## Your task

1. Find out why `kubectl` refuses changes to the Pruner ConfigMaps, and fix it.
2. Find out why the Pruner ignores the `starfleet` settings, and fix every reason. There is more than one.
3. Make the Pruner delete every finished run in `starfleet` 60 seconds after it ends, and leave `outpost` under the global default.

## Constraints

- Do not reinstall the Pruner, and do not change or delete the ValidatingWebhookConfiguration `validation.webhook.pruner.tekton.dev`.
- Do not set a TTL in the global configuration. Keep its `historyLimit: 100`.
- Do not delete TaskRuns by hand.

## Done when

- `tekton-pruner-webhook` has a ready replica, and the API server accepts changes to `tekton-pruner-default-spec`.
- The global configuration sets `enforcedConfigLevel: namespace` and no TTL.
- `starfleet` has the ConfigMap `tekton-pruner-namespace-spec`, with both Pruner labels and `ttlSecondsAfterFinished: 60`, and the old ConfigMap `tekton-pruner-namespace-config` is gone.
- A new run in `starfleet` is gone about a minute after it ends.
- A new run in `outpost` gets no TTL and is still there 30 seconds after it ends.
