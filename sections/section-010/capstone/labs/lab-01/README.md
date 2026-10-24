---
estimated_duration: 40m
---

# Repair A Broken Signing Setup

- **ID:** CAPSTONE
- **Slug:** ats-129-capstone-010
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for section 010, in the namespaces `tekton-chains` and `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

> **Not yet run.** This capstone was written from the Tekton Chains v0.29.9
> documentation and source and has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-129-capstone-010
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-capstone-010`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn, Tekton Pipelines and Chains, then the release key with a wrong password, `chains-config` without `storage.oci.repository.insecure`, and the broken Task `release-image` |
| `manifests/` | The namespaces, the registry, the workstation pod and its access to `signing-secrets`, the broken Task and the TaskRun `release-shuttle` |
| `solution/` | Reference solution used by `astrona test` |
| `testing/` | Waits for Tekton, the registry and the workstation |
| `validation/` | Grading scripts, one per check; the public key is checked against a copy taken at start |
