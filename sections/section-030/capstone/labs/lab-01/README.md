---
estimated_duration: 30m
---

# Repair Tekton Monitoring

- **ID:** CAPSTONE
- **Slug:** ats-129-capstone-030
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for section 030, in the namespaces `tekton-pipelines`, `monitoring` and `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

> **Not yet run.** This capstone was written from the Tekton Pipelines v1.17.1
> metrics documentation and source and has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-129-capstone-030
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-capstone-030`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn and Tekton Pipelines, then a run and `metrics-protocol: none` |
| `manifests/` | Prometheus with the Tekton job on port `8080` and the alert on `status="failure"`, the client pod, the Task |
| `solution/` | Reference solution used by `astrona test` |
| `testing/` | Waits for Tekton and Prometheus |
| `validation/` | Grading scripts, one per check; the last one runs a failing TaskRun |
