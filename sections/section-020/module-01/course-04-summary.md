# Summary

Running Tekton for a long time takes two things beyond the first install: one place that owns the installation and its upgrades, and rules that remove finished runs before they slow the cluster down.

## What you learned

The Tekton Operator installs and upgrades the Tekton components from one custom resource, the `TektonConfig` named `config`. Its profile picks the components: `lite` for Tekton Pipelines, `basic` adds Triggers and Chains, `all` adds the Dashboard on Kubernetes. The Operator creates one resource per component, such as `TektonPipeline` and `TektonPruner`, and tracks the objects it applied in `TektonInstallerSet` resources. Settings belong in the `TektonConfig`; the ConfigMaps the Operator writes are overwritten when it reconciles. Each Operator release pins every component version, so you upgrade by applying a newer Operator release and following `kubectl get tektonconfig` until it is ready again.

Tekton never deletes a finished run by itself. The Operator offers a job-based pruner that runs `tkn` on a schedule, and the event-based Tekton Pruner, which you can also install from its own release manifest. The event-based Pruner reacts when a run finishes. Its global rules live in the ConfigMap `tekton-pruner-default-spec` under `global-config`, written by the Operator from `spec.tektonpruner` or edited directly in a standalone installation.

There are two kinds of rules. History limits keep the newest runs of each status: `successfulHistoryLimit`, `failedHistoryLimit`, and `historyLimit` for any status without its own limit. A TTL, `ttlSecondsAfterFinished`, deletes a run a set number of seconds after it finished, whatever its status. Both work independently. With `enforcedConfigLevel: namespace`, each namespace can set its own rules in a ConfigMap named `tekton-pruner-namespace-spec` with the key `ns-config`. The key facts to remember are these:

- Change an Operator installation through the `TektonConfig`, never through the ConfigMaps it owns.
- The Operator runs only one pruner: disable `spec.pruner` to enable `spec.tektonpruner`.
- Namespace rules count only under `enforcedConfigLevel: namespace`, and only in `tekton-pruner-namespace-spec`.
- Every Pruner ConfigMap needs the labels `app.kubernetes.io/part-of: tekton-pruner` and `pruner.tekton.dev/config-type`; the webhook then validates it and refuses all changes while it is down.
- New rules reach old runs when the Pruner sees them again, for example after a restart of its controller.

<!-- astrona:playground:destroy -->
