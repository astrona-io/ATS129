# Welcome To The Course

This course trains you for the **Supply Chain Security With Chains & Operations** part of the Astrona **Tekton** training path. That part is 15% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You already run Tekton: you know that a `Task` is a list of steps, that a `TaskRun` is one execution of it with its own pod, and that Tekton Pipelines runs in the namespace `tekton-pipelines`. You know your way around Kubernetes: namespaces, pods, ConfigMaps, Secrets, Services, `kubectl apply`, `kubectl get` and `kubectl logs`. You do not need to know cosign, Sigstore, the Tekton Operator or Prometheus yet. Each new idea is explained the first time it appears.

## What you can do at the end

This course is about running Tekton safely and for a long time. It asks you to sign builds, clean up after them and watch them, and to find out why when one of those quietly stops working. The course has three topics, and each one turns into a set of skills you will practise.

The first topic is **supply chain security with Tekton Chains**. You will learn to:

- Explain what Tekton Chains does when a run ends, and why it never blocks a build.
- Give Chains a cosign key and configure its formats, storage and signers in `chains-config`.
- Make a Task report the image it built, so Chains signs it and pushes SLSA provenance to the registry.
- Verify signatures and attestations with `cosign`, and explain keyless signing with Fulcio and Rekor.

A signed build still leaves a run behind, so the second topic is **operating Tekton with the Operator and the Pruner**. You will learn to:

- Install, configure and upgrade Tekton with the Tekton Operator and a `TektonConfig`.
- Keep a fixed number of runs with history limits.
- Delete runs a set time after they finish, and give each namespace its own rules.

The third topic is **monitoring Tekton with Prometheus**. You will learn to:

- Read the metrics of the Tekton Pipelines controller and the ConfigMap that controls them.
- Make Prometheus scrape the controller and query the metrics with PromQL.
- Write alerting rules that fire when TaskRuns fail.

Everything is written for **Tekton Pipelines v1.17.1**, **Tekton Chains v0.29.9**, the **Tekton Pruner v0.4.4**, the **Tekton Operator v0.81.2**, **tkn v0.46.2** and **cosign 3.1.4**.

## The words this course uses

The pages use Tekton's, Sigstore's and Prometheus' own terms, because those are the words you meet in the product, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back often, so here they are up front.

| Term | What it is |
| --- | --- |
| Provenance | A signed record of how an artifact was built: by which run, from which inputs |
| SLSA | Supply-chain Levels for Software Artifacts, a security framework; its provenance format is what Chains writes |
| Attestation | A signed statement about an artifact, such as its provenance, stored next to it |
| cosign | The signing tool of the Sigstore project |
| `TektonConfig` | The custom resource in which you describe a whole Tekton installation for the Operator |
| TTL | Time to live: how long a finished run may stay before the Pruner deletes it |
| Scrape | One request from Prometheus to a metrics endpoint |

## The example setup in your playground

Every playground and lab runs on a small `kind` cluster with Tekton installed, except where installing it is the lesson. Your Tasks and TaskRuns live in the namespace `starfleet`, and some labs add a second team namespace, `outpost`. The example Tasks have short names, such as `build-image` or `nightly-check`, and the images they build are named after crew members, such as `bridge`, `shuttle` and `probe`.

Some environments add helpers: an image registry inside the cluster at `registry.localtest.me:5001`, a workstation pod with `cosign` and `regctl`, or a small Prometheus server with a client pod in the namespace `monitoring`. Many labs start with something broken on purpose: a run that looks signed but is not, a rule that the Pruner ignores, an alert that can never fire. That is the material, not a fault in the course.

## How the course is laid out

The course has three sections. It starts with signing builds, goes on with running and cleaning up the installation, and ends with watching it.

| Section | What it covers |
| --- | --- |
| 010 | Sign And Attest Builds With Tekton Chains |
| 020 | Operate Tekton With The Operator And The Pruner |
| 030 | Monitor Tekton With Prometheus |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.
