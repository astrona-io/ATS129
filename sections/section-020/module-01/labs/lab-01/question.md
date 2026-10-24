# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Operations

## Scenario

Thousands of finished TaskRuns pile up in the cluster, and the API server gets slower every week. The `starfleet` team never looks at a run after it ends. The `outpost` team wants to read its latest runs when a nightly check fails, but has no use for older ones. The standalone Tekton Pruner v0.4.4 is installed, but it still has its shipped configuration.

## Your task

1. Change the global Pruner configuration so that namespaces may have their own pruning settings. Keep the cluster-wide `historyLimit: 100`.
2. In `starfleet`, delete every finished run 60 seconds after it ends.
3. In `outpost`, keep the 3 newest successful runs and the 2 newest failed runs, with no time limit.

## Constraints

- Use the global ConfigMap `tekton-pruner-default-spec` in `tekton-pipelines` and one namespace ConfigMap `tekton-pruner-namespace-spec` in each team namespace. Every Pruner ConfigMap needs the labels `app.kubernetes.io/part-of: tekton-pruner` and `pruner.tekton.dev/config-type` (`global` or `namespace`).
- Do not delete TaskRuns by hand, and do not change the Pruner Deployments.
- Do not change the Task `nightly-check`.

## Done when

- `tekton-pruner-default-spec` sets `enforcedConfigLevel: namespace` and `historyLimit: 100`.
- `starfleet` has `tekton-pruner-namespace-spec` with `ttlSecondsAfterFinished: 60` in `ns-config`.
- `outpost` has `tekton-pruner-namespace-spec` with `successfulHistoryLimit: 3` and `failedHistoryLimit: 2` and no `ttlSecondsAfterFinished`.
- A new run in `starfleet` gets the annotation `pruner.tekton.dev/ttlSecondsAfterFinished: "60"` and is gone about a minute after it ends.
- After four new successful and three new failed runs in `outpost`, at most 3 successful and 2 failed runs remain, and the newest ones are kept.
