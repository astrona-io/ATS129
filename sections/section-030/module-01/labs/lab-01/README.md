---
estimated_duration: 25m
---

# Scrape Tekton And Alert On Failed TaskRuns

- **ID:** LAB
- **Slug:** ats-129-lab-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespaces `monitoring` and `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton Pipelines v1.17.1 metrics
documentation and source and has not passed `astrona validate` or `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-129-lab-030-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-lab-030-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn and Tekton Pipelines, then the Task `nightly-check` and one run |
| `manifests/` | The namespaces, Prometheus with its ConfigMap, the client pod and the Task |
| `solution/` | Reference solution used by `astrona test`: the full `prometheus-config` |
| `testing/` | Waits for Tekton and Prometheus |
| `validation/` | Grading scripts, one per check; the last one runs a failing TaskRun |
