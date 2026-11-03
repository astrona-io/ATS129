# Provenance Formats, Storage And Signers — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-129-playground-010-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A sandbox with Tekton Pipelines v1.17.1, Tekton Chains v0.29.9 (no key, default configuration), an in-cluster OCI registry at `registry.localtest.me:5001`, the workstation pod with cosign 3.1.4 and regctl 0.11.7, the tkn CLI 0.46.2 and an empty namespace `starfleet`. Nothing to submit.

Not yet run: this playground was written from the Tekton documentation and
the release manifests and has not been started on a cluster yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-129-playground-010-02
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-playground-010-02`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | Environment preparation run once at startup |
| `manifests/lab-start.yaml` | The namespaces `starfleet`, `registry` and `workstation`, the registry and the workstation pod |
| `manifests/workstation-access.yaml` | Lets the workstation pod read and write the Secrets in `tekton-chains` |
| `docs/overview.md` | What the environment contains and ideas to try |
