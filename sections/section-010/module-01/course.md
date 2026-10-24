# Signed Provenance With Tekton Chains

Your Task built an image and pushed it to a registry. A week later, someone asks: which run built this image, from which source, and was it changed afterwards? The registry cannot answer. A signature and a provenance record can, and Tekton Chains writes both for every run without any change to your Tasks.

Tekton Chains is a separate Tekton project: one controller in the namespace `tekton-chains`. It watches TaskRuns and PipelineRuns. When a run ends, the Chains controller writes a provenance record (what was built, by which run, with which inputs), signs it, and stores the signature and the record in the place you configured: on the run itself as annotations, or in an OCI registry next to the image.

Keep one sentence in mind: **Chains works after the run, never during it.** A run that Chains cannot sign still succeeds. That keeps builds fast, but it also means a broken signing setup fails quietly, so you always prove a signature with `cosign`, never with the run's status.

The module has three parts. **How Tekton Chains Works** shows what the controller does, gives Chains a cosign key and reads the first signed provenance. **Sign Images And Store Attestations In A Registry** uses the results `IMAGE_URL` and `IMAGE_DIGEST` to tell Chains which image a run built, and stores the signature and a SLSA provenance attestation in the registry. **Keyless Signing, Transparency Logs And Quiet Failures** covers Fulcio, Rekor and KMS keys, and the failures that leave a run marked as signed with nothing behind it. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Explain what Tekton Chains does when a TaskRun or PipelineRun ends, and why it never blocks a run.
- Give Chains a cosign key pair in the Secret `signing-secrets` in `tekton-chains`.
- Configure `chains-config`: payload format, storage backends, signer and transparency log.
- Write a Task whose results `IMAGE_URL` and `IMAGE_DIGEST` tell Chains which image it built.
- Store image signatures and SLSA provenance attestations in an OCI registry, and verify them with `cosign`.
- Explain keyless signing with Fulcio and the Rekor transparency log, and when to use a key pair or a KMS key instead.
- Read the Chains annotations and the controller log to find out why nothing was signed.

## Before you start

You need Kubernetes basics and Tekton basics: a `Task` is a list of steps, a `TaskRun` is one execution of a `Task` with its own pod, and a step can write a short value to a result. You should know what a container image, a tag and a digest are. You do not need to know cosign or Sigstore yet.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 |
| Namespace `tekton-chains` | Tekton Chains v0.29.9: the controller, an empty `signing-secrets` and an empty `chains-config` |
| `registry.localtest.me:5001` | An OCI registry inside the cluster, plain HTTP, lab-only |
| `deploy/workstation` in `workstation` | A pod with `cosign` 3.1.4, `regctl` 0.11.7, `curl` and `jq` |
| Namespace `starfleet` | Empty. Your Tasks and TaskRuns go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
