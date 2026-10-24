---
estimated_duration: 30m
---

# Repair Run Cleanup

- **ID:** CAPSTONE
- **Slug:** ats-129-capstone-020
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for section 020, in the namespaces `tekton-pipelines`, `starfleet` and `outpost`. Read `question.md` for the task; `solution.md` is the walkthrough.

> **Not yet run.** This capstone was written from the Tekton Pruner v0.4.4
> documentation and source and has not passed `astrona test` yet. Grading
> waits for real pruning and takes about four minutes.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-129-capstone-020
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-capstone-020`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, Tekton Pipelines and the Pruner, then runs, the wrongly named ConfigMap and the webhook scaled to zero |
| `manifests/` | The namespaces, the Task `nightly-check` and the wrongly named ConfigMap |
| `solution/` | Reference solution used by `astrona test` |
| `testing/` | Waits for the Deployments that are not scaled to zero |
| `validation/` | Grading scripts, one per check; the last two start their own runs |
