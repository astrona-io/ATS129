# ATS129 — Supply Chain Security With Chains & Operations (Tekton)

Course material for the **Supply Chain Security With Chains & Operations** domain of
the Astrona Tekton training path ([ATP024](https://github.com/astrona-io/ATP024)),
which is **15% of the path**. Written for **Tekton Pipelines v1.17.1**,
**Tekton Chains v0.29.9**, the **Tekton Pruner v0.4.4**, the **Tekton Operator
v0.81.2**, the **tkn CLI v0.46.2** and **cosign 3.1.4**.

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the Tekton documentation, the release manifests and the source at the
> pinned tags. None has been started on a cluster, and no lab has passed
> `astrona test` yet. See `CLAUDE.md`.

Tekton is an incubating project of the Cloud Native Computing Foundation
(CNCF) since March 2026; before that it was a graduated project of the
Continuous Delivery Foundation. There is no official Tekton certification
exam; the path's domains and weights are Astrona's own.

The course opens with an Introduction in `sections/intro/` (welcome, machine setup,
how the course is made). Everything else lives under `sections/`. Each section
contains:

- **Modules** — a reading chapter split into a short landing page, ordered
  deep-dive parts and a summary page, a throwaway **playground** to explore in,
  and a graded **lab** placed right after the part it tests.
- **A capstone** — one larger graded lab combining that section's modules into a
  single scenario with several independent faults.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | Sign And Attest Builds With Tekton Chains | 2 | 2 + capstone | Supply chain security |
| [020](sections/section-020) | Operate Tekton With The Operator And The Pruner | 2 | 2 + capstone | Operations |
| [030](sections/section-030) | Monitor Tekton With Prometheus | 2 | 2 + capstone | Monitoring |

The order follows a build's life: sign what a run produced, clean up the
runs afterwards, and watch the installation that runs them.

---

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Signed Provenance With Tekton Chains](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Manage Tekton With The Operator And The Pruner](sections/section-020/module-01/course.md) | 3 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Monitor Tekton With Prometheus](sections/section-030/module-01/course.md) | 3 | [lab-01](sections/section-030/module-01/labs/lab-01) |
| 010-02 | [Provenance Formats, Storage Backends And Signers](sections/section-010/module-02/course.md) | 4 | [lab-01](sections/section-010/module-02/labs/lab-01) |
| 020-02 | [Configure Tekton Components Through TektonConfig](sections/section-020/module-02/course.md) | 4 | [lab-01](sections/section-020/module-02/labs/lab-01) |
| 030-02 | [Query And Tune Tekton Metrics](sections/section-030/module-02/course.md) | 4 | [lab-01](sections/section-030/module-02/labs/lab-01) |

| Lab | Title | Kind | Faults or work |
| --- | --- | --- | --- |
| 010-01 | Sign Built Images With Tekton Chains | build | no signing key, default `chains-config`, results not type-hinted; the run still says `signed: "true"` |
| 020-01 | Configure Time-Based And History-Based Pruning | build | shipped Pruner configuration; add namespace level, a 60-second TTL in `starfleet`, history limits in `outpost` |
| 030-01 | Scrape Tekton And Alert On Failed TaskRuns | build | Prometheus scrapes only itself; add the Tekton job and a failed-run alert |
| 010-02 | Choose Chains Provenance Format And Storage | build | provenance in the default format and only in annotations; switch to `slsa/v2alpha4` and add `oci` storage |
| 020-02 | Tune Tekton Pipelines Through The TektonConfig | build | a `lite` TektonConfig with defaults; set `enable-api-fields`, `default-timeout-minutes` and a `config-logging` key |
| 030-02 | Record Failure Ratio And Alert On Stuck TaskRuns | build | Prometheus scrapes the controller; add a recording rule and a running-runs alert |

---

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Repair A Broken Signing Setup | wrong `cosign.password` for the release key, `IMAGE_DIGEST` without `sha256:`, no `storage.oci.repository.insecure` for the HTTP registry |
| [020](sections/section-020/capstone/labs/lab-01) | Repair Run Cleanup | Pruner webhook scaled to zero, `enforcedConfigLevel: global`, namespace ConfigMap with the wrong name |
| [030](sections/section-030/capstone/labs/lab-01) | Repair Tekton Monitoring | `metrics-protocol: none`, scrape job on the `probes` port, alert on `status="failure"` |

---

## The lab environment

Every playground and lab is a single-node **kind** cluster with the `tkn` CLI
0.46.2 on the machine and a namespace `starfleet`.

| Section | What runs in the cluster |
| --- | --- |
| 010 | Tekton Pipelines v1.17.1, Tekton Chains v0.29.9, a plain-HTTP registry (`registry:3.1.2`) reachable cluster-wide as `registry.localtest.me:5001` through a CoreDNS rewrite, and a workstation pod (`alpine:3.22`) with cosign 3.1.4 and regctl 0.11.7 that may write `signing-secrets`. Builds use `ghcr.io/regclient/regctl:v0.11.7-alpine` to create images from scratch |
| 020 | Playground: the Tekton Operator v0.81.2 only, with `AUTOINSTALL_COMPONENTS` switched off (it installs Pipelines v1.15.3 and Pruner v0.4.3 once the reader creates a `TektonConfig`). Lab and capstone: Tekton Pipelines v1.17.1 and the standalone Pruner v0.4.4 |
| 030 | Tekton Pipelines v1.17.1, Prometheus `prom/prometheus:v3.15.1` and a client pod `nicolaka/netshoot:v0.13` in `monitoring` |

No lab uses public Sigstore services: Chains signs with a cosign key pair and
`transparency.enabled: "false"`; keyless signing is taught in prose. Tekton's
own images come from `ghcr.io` (and `cgr.dev`), and the workstation downloads
cosign and regctl from GitHub, so every start needs outbound internet.

Graders verify signatures with cosign in the workstation pod, wait for the
Pruner to delete real runs, and query Prometheus from the client pod. Several
graders create TaskRuns of their own (`generateName`, label
`astrona.io/grader: "true"`). No script uses a fixed host port.

## Running a playground

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/<section>/<module>/playground
astrona destroy <name>
```

## Running a lab

Labs and capstones are graded. Read `question.md`, do the work, and submit:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```

Each lab grades the **final cluster state** with independent checks, and
several of them deliberately reject the plausible-but-wrong fix (trusting the
`chains.tekton.dev/signed` annotation, replacing the release key, a global TTL
instead of a namespace rule, an alert that never matches).
