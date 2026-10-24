---
estimated_duration: 25m
---

# Configure Time-Based And History-Based Pruning

- **ID:** LAB
- **Slug:** ats-129-lab-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespaces `tekton-pipelines`, `starfleet` and `outpost`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton Pruner v0.4.4 documentation
and source and has not passed `astrona validate` or `astrona test` yet. The
behaviour checks wait for real pruning, so grading takes about five minutes.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-129-lab-020-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-lab-020-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, Tekton Pipelines and the standalone Pruner, then three runs of `nightly-check` in each namespace |
| `manifests/` | The namespaces `starfleet` and `outpost` and the Task `nightly-check` |
| `solution/` | Reference solution used by `astrona test`: the three Pruner ConfigMaps |
| `testing/` | Waits for the Tekton and Pruner Deployments |
| `validation/` | Grading scripts, one per check; the last two start their own runs and wait for the Pruner |
