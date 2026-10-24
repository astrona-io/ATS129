# Section 020: Operate Tekton With The Operator And The Pruner

Installing Tekton once is easy. Running it for years is harder: every component needs upgrades, every setting needs a single place where it lives, and every finished run stays in the cluster until someone deletes it. Thousands of old TaskRuns and their pods slow down the API server and the controllers. This section covers both jobs: managing the installation with the Tekton Operator, and cleaning up runs with the Tekton Pruner.

You first install Tekton through the Operator with a single `TektonConfig`, read how the Operator reports its state, and learn how an Operator upgrade works. Then you switch on the event-based Tekton Pruner and keep a fixed number of runs per status. Last, you delete runs a set time after they finish, give each namespace its own rules, and see how the Pruner webhook protects its configuration.

**Topic covered:** Operations

## What you will learn

- What the Tekton Operator manages: `TektonConfig`, the component resources such as `TektonPipeline` and `TektonPruner`, and `TektonInstallerSet`.
- Installing Tekton with a `TektonConfig` and a profile (`lite`, `basic`, `all`), and changing settings through it.
- How an Operator upgrade upgrades the components, and why one Operator release pins every component version.
- The job-based pruner (`spec.pruner`) and the event-based Tekton Pruner (`spec.tektonpruner` or the standalone release).
- History-based pruning with `successfulHistoryLimit`, `failedHistoryLimit` and `historyLimit`.
- Time-based pruning with `ttlSecondsAfterFinished`.
- `enforcedConfigLevel`, the global ConfigMap `tekton-pruner-default-spec` and the namespace ConfigMap `tekton-pruner-namespace-spec`, with their labels and webhook validation.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the last part, and a summary. The module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Manage Tekton With The Operator And The Pruner

The module starts at its landing page, which also launches the playground. The playground runs only the Tekton Operator v0.81.2: installing Tekton through it is the first hands-on step. The graded lab and capstone install Tekton Pipelines v1.17.1 and the standalone Pruner v0.4.4 from their release manifests instead.

1. Install And Configure Tekton With The Operator
2. Keep A Fixed Number Of Runs With History Limits
3. Delete Old Runs With TTLs And Namespace Settings, followed by the lab **Configure Time-Based And History-Based Pruning**
4. Summary

## Section capstone: Repair Run Cleanup

The capstone is one graded scenario that combines the whole module. The `starfleet` team asked for its runs to be deleted one minute after they end, but they never are, and `kubectl` refuses every change to the Pruner configuration. Bring the Pruner webhook back, find the two reasons why the Pruner ignores the team's settings, and prove the fix with runs that disappear on time while another namespace keeps its runs. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-129-capstone-020
```
