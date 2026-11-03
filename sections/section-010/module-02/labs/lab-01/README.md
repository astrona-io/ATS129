---
estimated_duration: 30m
---

# Choose Chains Provenance Format And Storage

- **ID:** LAB
- **Slug:** ats-129-lab-010-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespaces `starfleet` and `tekton-chains`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton Chains v0.29.9 documentation
and source and has not passed `astrona validate` or `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-129-lab-010-02
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-lab-010-02`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, Tekton Pipelines and Chains, the CoreDNS rewrite, the signing key, the starting `chains-config`, the Task `build-image` and the TaskRun `build-bridge` |
| `manifests/` | The namespaces, the registry, the workstation pod, its access to `signing-secrets`, and the starting Task and TaskRun |
| `solution/` | Reference solution used by `astrona test` |
| `testing/` | Waits for Tekton, the registry and the workstation |
| `validation/` | Grading scripts, one per check; the last one runs its own build |
