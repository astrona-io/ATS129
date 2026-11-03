---
estimated_duration: 25m
---

# Record Failure Ratio And Alert On Stuck TaskRuns

- **ID:** LAB
- **Slug:** ats-129-lab-030-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespaces `monitoring` and `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton Pipelines v1.17.1 metrics
documentation and source and has not passed `astrona validate` or `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-129-lab-030-02
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-lab-030-02`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn and Tekton Pipelines, then the Tasks `nightly-check` and `slow-check` and two runs |
| `manifests/` | The namespaces, Prometheus with its ConfigMap, the client pod and the Tasks |
| `solution/` | Reference solution used by `astrona test`: the full `prometheus-config` with both rules |
| `testing/` | Waits for Tekton and Prometheus |
| `validation/` | Grading scripts, one per check; the last one starts three slow TaskRuns |
