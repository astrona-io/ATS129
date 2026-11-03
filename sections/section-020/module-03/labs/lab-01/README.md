---
estimated_duration: 25m
---

# Add And Configure Tekton Triggers Through The TektonConfig

- **ID:** LAB
- **Slug:** ats-129-lab-020-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `tekton-pipelines` and the `TektonConfig`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton Operator v0.81.2 documentation
and has not passed `astrona validate` or `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-129-lab-020-03
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-lab-020-03`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn and the Tekton Operator, then a `TektonConfig` with the profile `lite` |
| `manifests/` | The namespace `starfleet` and the service account `triggers-sa` |
| `solution/` | Reference solution used by `astrona test`: the changed `TektonConfig` |
| `testing/` | Waits for the `TektonConfig` and the Deployments |
| `validation/` | Grading scripts, one per check; the checks wait for the Operator to install Triggers |
