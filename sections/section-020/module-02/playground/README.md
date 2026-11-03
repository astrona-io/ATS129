# Configure Tekton Components Through TektonConfig — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-129-playground-020-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A sandbox with the Tekton Operator v0.81.2, a `TektonConfig` named `config` with the profile `lite` (Tekton Pipelines v1.15.3, installed and Ready), the tkn CLI 0.46.2 and an empty namespace `starfleet`. The bootstrap switches `AUTOINSTALL_COMPONENTS` off in the Operator's release manifest and creates the `TektonConfig` itself. Nothing to submit.

Operator v0.81.2 installs Tekton Pipelines v1.15.3, not the v1.17.1 that other environments install from a release manifest. The pages say so.

Not yet run: this playground was written from the Tekton Operator documentation
and the v0.81.2 release manifest and has not been started on a cluster yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-129-playground-020-02
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-playground-020-02`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | Environment preparation run once at startup |
| `manifests/lab-start.yaml` | The namespace `starfleet` |
| `docs/overview.md` | What the environment contains and ideas to try |
