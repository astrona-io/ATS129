# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS129 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **Supply Chain Security With Chains & Operations**
  domain of the **Tekton** training path (`ATP024`). It is 15% of the path.
  There is no official Tekton certification exam; the path's domains and
  weights are Astrona's own, set in `ATP024/path.yaml` (10/20/25/15/15/15 for
  ATS124 to ATS129).
- **Where Tekton sits:** Tekton is an **incubating project of the Cloud Native
  Computing Foundation (CNCF)**. The CNCF accepted it on 13 March 2026. Before
  that it was a founding and graduated project of the Continuous Delivery
  Foundation (CD Foundation). It is **not** a CNCF graduated project, and it is
  no longer a CD Foundation project. Both foundations belong to the Linux
  Foundation. Sigstore (cosign, Fulcio, Rekor) is an OpenSSF project, not a
  Tekton or CNCF project. Say this correctly wherever the course mentions it.
- **What the domain really tests:** running Tekton safely, not remembering
  words. The student must *do* things (give Chains a key, configure
  `chains-config`, write type-hinting results, verify with `cosign`, configure
  the Pruner, scrape and alert with Prometheus). Every fix is proved with
  behaviour: a `cosign verify` that passes, a run that the Pruner deletes, an
  alert that fires after a real failure.
- **The three topics:** Tekton Chains and signed provenance, operating Tekton
  with the Operator and the Pruner, and monitoring with Prometheus.
- **The sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | Sign And Attest Builds With Tekton Chains | Supply chain security |
  | 020 | Operate Tekton With The Operator And The Pruner | Operations |
  | 030 | Monitor Tekton With Prometheus | Monitoring |

- **The versions:** **Tekton Pipelines v1.17.1**, **Tekton Chains v0.29.9**
  (built against Pipelines v1.15.2, uses the `tekton.dev/v1` API, works with
  v1.17.1), the standalone **Tekton Pruner v0.4.4** (built against Pipelines
  v1.12.0), the **Tekton Operator v0.81.2**, **tkn v0.46.2** and **cosign
  3.1.4**. Operator v0.81.2 installs its own pinned components: Pipelines
  **v1.15.3**, Triggers v0.37.1, Chains v0.29.7, Dashboard v0.71.0, Pruner
  v0.4.3, Results v0.20.0, Pipelines-as-Code v0.50.1. Only the section 020
  playground uses the Operator; every graded lab installs from release
  manifests. Pipelines 1.17 needs Kubernetes 1.28 or later (Chains too). v1.17
  is a monthly release (end of life 31 October 2026); the current LTS is v1.15.
  Do not teach fields, flags or output from other versions without saying so.
- **The main sources:** <https://tekton.dev/docs/>, and the `docs/` folders of
  `tektoncd/chains` (tag `v0.29.9`), `tektoncd/pruner` (`v0.4.4`),
  `tektoncd/operator` (`v0.81.2`), `tektoncd/pipeline` (`v1.17.1`,
  `docs/metrics.md`) and `sigstore/cosign` (`v3.1.4`). Several facts below
  come from the source code at these tags, not from the documentation.

### Status: every environment passes `astrona test`

All nine environments (three playgrounds, three labs, three capstones) passed
`astrona test` on 2026-10-25 on a laptop `kind` cluster with Podman. Pages
still describe results in words: add a `text` output block only when it is
pasted exactly from a real run. Run `astrona test` again on every environment
you change.

### Terms, not metaphors

Explanations use Tekton's, Sigstore's and Prometheus' own words. Define each
one in plain technical language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| Tekton Chains | A Tekton controller that watches finished TaskRuns and PipelineRuns, writes provenance, signs it and stores it |
| SLSA | Supply-chain Levels for Software Artifacts, a security framework; its provenance format is what Chains writes |
| Provenance | A signed record of how an artifact was built: by which run, from which inputs |
| in-toto statement | A JSON document with a `subject` (the artifacts), a `predicateType` and a `predicate` |
| Attestation | A signed in-toto statement stored next to an artifact |
| DSSE | Dead Simple Signing Envelope, the JSON wrapper that holds a payload and its signature |
| Type hinting | Result names (`*IMAGE_URL`/`*IMAGE_DIGEST`, `IMAGES`, `*ARTIFACT_OUTPUTS`, `CHAINS-GIT_URL`/`CHAINS-GIT_COMMIT`) that tell Chains the outputs and inputs of a run |
| cosign | The Sigstore signing tool; signs and verifies images, blobs and attestations |
| Fulcio / Rekor | The Sigstore certificate authority for short-lived keyless certificates / the Sigstore transparency log |
| Tekton Operator | A Kubernetes operator that installs, configures and upgrades the Tekton components from a `TektonConfig` |
| `TektonInstallerSet` | The set of plain objects the Operator applied for one component |
| Tekton Pruner | A controller that deletes finished TaskRuns and PipelineRuns by history limits or a TTL |
| TTL | Time to live: `ttlSecondsAfterFinished`, the seconds a finished run may stay |
| Scrape | One request from Prometheus to a metrics endpoint |
| Alerting rule | A named PromQL expression that Prometheus evaluates; `inactive`, `pending`, `firing` |

The annotation `chains.tekton.dev/signed` and a real signature are the most
confused pair. Always say that the annotation is not proof.

### The example workloads

| Name | Image | What it is |
| --- | --- | --- |
| Namespace `starfleet` | | Where every Task and TaskRun of the course runs |
| Namespace `outpost` | | Second team namespace in the section 020 lab and capstone |
| Task `build-image` / `release-image` | `ghcr.io/regclient/regctl:v0.11.7-alpine` | Creates a scratch image with `regctl image create`, pushes it to `registry.localtest.me:5001/starfleet/<name>` and writes `IMAGE_URL` and `IMAGE_DIGEST` |
| Task `hello` | `busybox:1.37.0` | Hello-world Task for the first Chains run |
| Task `nightly-check` | `busybox:1.37.0` | One step; `outcome=pass` succeeds, `outcome=fail` fails (sections 020 and 030) |
| Images `bridge`, `scout`, `shuttle`, `probe` | | Image names in the lab registry |
| `deploy/workstation` in `workstation` | `alpine:3.22` + cosign 3.1.4, regctl 0.11.7 | Signing and verifying client; its ServiceAccount may write Secrets in `tekton-chains` (`workstation-access.yaml`) |
| `deploy/registry` in `registry` | `registry:3.1.2` | Plain-HTTP OCI registry on port 5001 (debug server moved to 5002) |
| `deploy/prometheus`, `deploy/client` in `monitoring` | `prom/prometheus:v3.15.1`, `nicolaka/netshoot:v0.13` | Prometheus configured by the ConfigMap `prometheus-config` (`prometheus.yml`, `tekton-rules.yml`), and a pod with `curl` and `jq` |

Every step uses a `script`, never a bare image without `command`.

### Environment facts the text must respect

- **Install from the release manifests.** Pipelines:
  `https://infra.tekton.dev/tekton-releases/pipeline/previous/v1.17.1/release.yaml`.
  Chains: `.../chains/previous/v0.29.9/release.yaml`. Pruner:
  `.../pruner/previous/v0.4.4/release.yaml`. Operator:
  `.../operator/previous/v0.81.2/release.yaml`.
- **Chains (checked in the v0.29.9 manifest and source):** namespace
  `tekton-chains`; Deployment `tekton-chains-controller`; empty Secret
  `signing-secrets` (mounted at `/etc/signing-secrets`); ConfigMap
  `chains-config` with no data (defaults: `artifacts.taskrun.format: in-toto`,
  `artifacts.taskrun.storage: tekton`, `artifacts.taskrun.signer: x509`,
  `artifacts.oci.storage: oci`, `artifacts.oci.format: simplesigning`,
  `transparency.enabled: false`, `storage.oci.encoding-format: dsse`);
  ConfigMap `chains-info` (key `version`); Service `tekton-chains-metrics`
  port 9090. Formats: `in-toto` and `slsa/v1` write SLSA v0.2
  (`cosign --type slsaprovenance`); `slsa/v2alpha3` and `slsa/v2alpha4` write
  SLSA v1.0 (`--type slsaprovenance1`). Invalid values for a format key are
  rejected by the config parser.
- **Chains behaviour (from the source):** the signer is built from
  `signing-secrets` at every signing. No key or a wrong `cosign.password` means
  no signer; Chains logs it, skips signing and still sets
  `chains.tekton.dev/signed: "true"`. A digest result without `sha256:` gives no
  subject (logged `error getting digest`), again `signed: "true"`. A storage
  error adds `chains.tekton.dev/retries`; after 3 retries it sets
  `signed: "failed"`. A run with `signed` `true` or `failed` is never handled
  again. Tekton storage annotations: `chains.tekton.dev/payload-taskrun-<uid>`,
  `signature-taskrun-<uid>`, `cert-taskrun-<uid>`, `chain-taskrun-<uid>`.
- **Insecure registry:** `storage.oci.repository.insecure: "true"` adds
  `name.Insecure` (HTTP fallback) and skips TLS verification. Registry names
  ending in `.local` or `localhost:` would use HTTP anyway, which is why the
  labs use `registry.localtest.me:5001` (CoreDNS rewrite to
  `registry.registry.svc.cluster.local`, copied from ATS118/119).
- **cosign 3.1.4:** `cosign generate-key-pair k8s://tekton-chains/signing-secrets`
  writes `cosign.key`, `cosign.pub`, `cosign.password`, updates an existing
  Secret and marks it **immutable**; `COSIGN_PASSWORD` avoids the prompt.
  Verification in labs: `cosign verify|verify-attestation --key ...
  --insecure-ignore-tlog --allow-http-registry`. `verify-attestation` falls
  back to the legacy layout when no bundle is found through referrers.
- **Pruner (checked in the v0.4.4 manifest and source):** Deployments
  `tekton-pruner-controller` and `tekton-pruner-webhook` in
  `tekton-pipelines`; global ConfigMap `tekton-pruner-default-spec` (key
  `global-config`, shipped `enforcedConfigLevel: global`, `historyLimit: 100`);
  namespace ConfigMap must be named `tekton-pruner-namespace-spec` (key
  `ns-config`; the controller filters on the name only). Labels
  `app.kubernetes.io/part-of: tekton-pruner` and `pruner.tekton.dev/config-type:
  global|namespace` select the ValidatingWebhookConfiguration
  `validation.webhook.pruner.tekton.dev` (`failurePolicy: Fail`). Namespace
  ConfigMaps count only with `enforcedConfigLevel: namespace`. Annotations on
  runs: `pruner.tekton.dev/ttlSecondsAfterFinished` (`-1` means none) and
  `pruner.tekton.dev/historyLimitCheckProcessed`. Standalone TaskRuns only (a
  TaskRun of a PipelineRun is handled through the PipelineRun). Event driven:
  already finished runs get new rules only when reconciled again (restart of
  the controller). System maximums: TTL 2,592,000 s, limits 100.
- **Operator (checked in the v0.81.2 manifest and docs):** namespace
  `tekton-operator`, Deployments `tekton-operator` and
  `tekton-operator-webhook`; ConfigMap `tekton-config-defaults`
  (`AUTOINSTALL_COMPONENTS: "true"`, `DEFAULT_TARGET_NAMESPACE:
  tekton-pipelines`). `TektonConfig` `config`: `profile` `lite|basic|all`,
  `targetNamespace`, `pipeline.*` (feature flags and defaults), `pruner`
  (job-based, `tkn` CronJob) and `tektonpruner` (event-based, `global-config`);
  only one pruner at a time. Printer columns `Version`, `Ready`, `Reason`.
- **Metrics (checked in v1.17.1 `docs/metrics.md` and source):** OpenTelemetry;
  `config-observability` `metrics-protocol: prometheus|grpc|http/protobuf|none`;
  port `http-metrics` 9090 on the controller, webhook, events controller and
  resolvers Services (`probes` 8080, `http-profiling` 8008). Counter
  `tekton_pipelines_controller_taskrun_total{status}` with `success`, `failed`,
  `cancelled`; histograms `..._taskrun_duration_seconds`; gauges
  `..._running_taskruns`. Every series has `otel_scope_name`.
- **Prometheus in the labs:** static scrape target
  `tekton-pipelines-controller.tekton-pipelines.svc:9090`; 15-second scrape
  and evaluation; files read only at start (restart the Deployment). Graders
  query from `deploy/client` with `curl` and `jq`.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections and modules tables, how to run things | `README.md` |
| Introduction (see "Every course starts with an Introduction") | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-01/` (`question.md`, `solution.md`, `prerequisites.md`, `bootstrap/`, `manifests/`, `solution/`, `testing/`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` points at `question.md` and `solution.md` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `prerequisites.md` | What the learner needs before starting |
| `question.md` | The task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough |
| `bootstrap/01-install-tekton.sh`, `02-seed-state.sh` | tkn and the Tekton components of the lab (one shared script, switched by the variables at its top), then the starting state |
| `manifests/` | `lab-start.yaml` (namespaces and helper workloads) and the seeded objects |
| `solution/apply.sh` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-tekton.sh` | Waits until the Deployments answer before the reference solution runs |
| `validation/validate-*.sh` | Behavioural grading, one script per check |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS129`, domain
`Supply Chain Security With Chains & Operations`, weight `15`) and one entry
per section under `modules:` (`module-010`, `module-020`, `module-030`). Each
section's `content` lists, in order: the section `README.md`, then for each
module its landing page, its parts, and right after the part a lab tests, a
`Question` reading (`labs/lab-01/question.md`) followed by the `type: lab`
entry; the module's closing page comes last. The section capstone closes the
section. Playgrounds are not listed.

Every `type: lab` entry carries the same fields, in the same order, as in
ATS016: `title`, `path`, `difficulty`, `estimated_duration`, `topic`,
`task_kind`, `tags`, `learning_goals`, `resources`.

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`.
- `topic`: exactly one of `supply-chain-security`, `operations`, `monitoring`.
- `task_kind`: exactly one of `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb.
- `resources`: 1 to 4 pages on `tekton.dev`, each with a `name` and a `url`
  that loads. This is the **only** place outside links are allowed.

**Tag list** (lower case, hyphens, never synonyms):

- Supply chain security: `chains`, `signing-secrets`, `chains-config`,
  `type-hinting`, `slsa-provenance`, `oci-storage`, `cosign`,
  `transparency-log`, `keyless-signing`
- Operations: `operator`, `tektonconfig`, `pruner`, `ttl-pruning`,
  `history-pruning`, `namespace-pruning-config`, `pruner-webhook`
- Monitoring: `prometheus`, `metrics`, `config-observability`,
  `scrape-config`, `alerting-rules`, `promql`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-010/module-01/playground
astrona destroy ats-129-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-129-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names: a playground is `ats-129-playground-<section>-<module>`, a module lab
is `ats-129-lab-<section>-<module>` and a capstone is
`ats-129-capstone-<section>`; keep those names. Lab bootstrap scripts do not
pin a kube context: astrona sets `KUBECONFIG` for the lab. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **behaviour**, not just that an object exists: `cosign verify`
and `cosign verify-attestation` against the registry, a grader TaskRun that
must be signed, a grader TaskRun that the Pruner must delete (or keep), and an
alert that must fire after a grader TaskRun fails. Graders also reject the
plausible but wrong fix (trusting `chains.tekton.dev/signed`, a new key pair
instead of the release key, a global TTL, deleting runs by hand, an alert that
never matches). A lab's `question.md` and `solution.md` must match what its
`validation/` scripts actually check.

The install scripts are generated from one template; when you change one,
change all nine (`bootstrap/01-install-tekton.sh` and `playground/bootstrap/prepare.sh`).
No script uses a fixed host port: graders reach the registry and Prometheus
from pods inside the cluster.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

- **Chains:** [overview](https://tekton.dev/docs/chains/),
  [configuration](https://tekton.dev/docs/chains/config/),
  [signing](https://tekton.dev/docs/chains/signing/),
  [SLSA provenance](https://tekton.dev/docs/chains/slsa-provenance/),
  [Sigstore](https://tekton.dev/docs/chains/sigstore/)
- **Operator:** [overview](https://tekton.dev/docs/operator/),
  [TektonConfig](https://tekton.dev/docs/operator/tektonconfig/),
  [TektonPruner](https://tekton.dev/docs/operator/tektonpruner/)
- **Pruner:** [Tekton Pruner](https://tekton.dev/docs/pruner/) and
  `docs/tutorials/` in `tektoncd/pruner` at `v0.4.4`
- **Metrics:** [pipeline controller metrics](https://tekton.dev/docs/pipelines/metrics/)
- **Source:** `pkg/chains/` in `tektoncd/chains` at `v0.29.9`, `pkg/config/` in
  `tektoncd/pruner` at `v0.4.4`, `pkg/taskrunmetrics/` in `tektoncd/pipeline`
  at `v1.17.1`

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository:
planning (`domain-plan`), creating the tree (`domain-scaffold`), building
modules (`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds
(`lab`), lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).
