# Manage Tekton With The Operator And The Pruner

A Tekton installation from release manifests is a pile of YAML files that you apply by hand, one per component, and upgrade by hand, one at a time. Settings end up in a dozen ConfigMaps. Meanwhile every TaskRun stays in the cluster after it finishes, with its pod, until somebody deletes it. Both problems grow with time, and this module solves both.

The Tekton Operator is a controller that installs and upgrades the Tekton components for you. You describe the installation in one custom resource, `TektonConfig`, and the Operator creates and updates everything else. The Tekton Pruner is a controller that deletes finished TaskRuns and PipelineRuns by rules you set: keep the newest few, or delete each run some time after it ends. The Operator can install the Pruner, and the Pruner also has its own release manifest.

Keep one sentence in mind: **the Operator owns what it installs, and the Pruner acts on events.** With the Operator, you change settings in `TektonConfig`, not in the ConfigMaps it writes. The Pruner looks at a run when the run changes, for example when it finishes, so new rules reach old runs only when the Pruner sees them again.

The module has three parts. **Install And Configure Tekton With The Operator** installs Tekton through a `TektonConfig`, reads the Operator's status, and explains upgrades. **Keep A Fixed Number Of Runs With History Limits** switches on the event-based Pruner and keeps a set number of successful and failed runs. **Delete Old Runs With TTLs And Namespace Settings** deletes runs by age and gives each namespace its own rules. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Name the custom resources of the Tekton Operator and say what each one does.
- Install Tekton with a `TektonConfig` and a profile, read its `Ready` condition and version, and change a setting through it.
- Explain how an Operator upgrade upgrades the components it manages.
- Tell the job-based pruner from the event-based Tekton Pruner, and enable the event-based one.
- Configure history-based pruning with `successfulHistoryLimit`, `failedHistoryLimit` and `historyLimit`.
- Configure time-based pruning with `ttlSecondsAfterFinished`.
- Give a namespace its own rules with `enforcedConfigLevel: namespace` and `tekton-pruner-namespace-spec`, and read the Pruner webhook's errors.

## Before you start

You need Kubernetes basics and Tekton basics: a `Task` is a list of steps, a `TaskRun` is one execution of it with its own pod, and Tekton Pipelines runs in the namespace `tekton-pipelines`. You should know what a custom resource and an admission webhook are.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-operator` | The Tekton Operator v0.81.2: `tekton-operator` and `tekton-operator-webhook` |
| No `TektonConfig` | Tekton itself is not installed yet; you install it through the Operator |
| Namespace `starfleet` | Empty. Your Tasks and TaskRuns go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

The Operator v0.81.2 installs Tekton Pipelines v1.15.3 and the Tekton Pruner v0.4.3. The graded lab installs Pipelines v1.17.1 and the standalone Pruner v0.4.4 from their release manifests; the Pruner settings are the same in both.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
