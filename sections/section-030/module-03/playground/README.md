# Query And Tune Tekton Metrics — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-129-playground-030-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A sandbox with Tekton Pipelines v1.17.1, Tekton Chains v0.29.9 (no signing key), the Tekton Pruner v0.4.4, the tkn CLI 0.46.2, an empty namespace `starfleet`, and in `monitoring` a Prometheus v3.15.1 server that scrapes itself and the Pipelines controller plus a client pod with `curl` and `jq`. Nothing to submit.

Not yet run: this playground was written from the Tekton documentation and
the v1.17.1 release manifest and has not been started on a cluster yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-129-playground-030-03
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-129-playground-030-03`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | Environment preparation run once at startup |
| `manifests/lab-start.yaml` | The namespaces, Prometheus and Alertmanager with their ConfigMaps, and the client pod |
| `docs/overview.md` | What the environment contains and ideas to try |
