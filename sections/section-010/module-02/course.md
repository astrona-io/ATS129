# Provenance Formats, Storage Backends And Signers

Module one got Chains to sign an image. This module answers the questions an auditor asks next. Which format is the provenance in, and which tools can read it? Where does it live, and can it be read without access to the cluster? Which key signed it, and what happens when that key changes? Every answer is a line in `chains-config`.

`chains-config` is organised by artifact type. Chains knows three: `taskrun` for the provenance of a TaskRun, `pipelinerun` for the provenance of a PipelineRun, and `oci` for the images that runs build. Each type has its own `format`, `storage` and `signer` key, so one cluster can write SLSA v1.0 provenance for TaskRuns, keep PipelineRun provenance on the run, and sign images in a registry, all at once.

Keep one sentence in mind: **format is the shape, storage is the place, signer is the key.** Three settings per artifact type, and a wrong value in any one of them fails quietly, because Chains works after the run.

The module has four parts. **Pick A Provenance Format** compares `in-toto`, `slsa/v1`, `slsa/v2alpha3` and `slsa/v2alpha4` by what is inside the statement. **Choose Where Chains Stores Provenance** covers the `tekton` and `oci` backends and the keys for the others. A graded lab follows this second part. **Provenance For PipelineRuns And Images** applies the same three settings to the other artifact types. **Signers, Keys And Offline Verification** covers `x509` and `kms` signers, key rotation, and verifying an annotation without the cluster.

## Learning objectives

After this module you can:

- Name the four TaskRun provenance formats, the SLSA version of each, and the `predicateType` each writes.
- Read the fields of a SLSA v0.2 and a SLSA v1.0 statement and find the builder, the build type and the inputs.
- Store provenance in the TaskRun annotations, in an OCI registry, or in both, and find it in each place.
- Name the keys of the storage backends `gcs`, `docdb`, `grafeas` and `archivista`.
- Configure PipelineRun provenance and explain what deep inspection changes.
- Choose between the `x509` and `kms` signers and rotate a signing key without breaking verification of old artifacts.
- Verify a payload from an annotation with `cosign`, without access to the cluster.

## Before you start

You should have finished module one, or know what it taught: Chains handles a finished run once, it writes the annotation `chains.tekton.dev/signed`, it finds an image through the results `IMAGE_URL` and `IMAGE_DIGEST`, and a signing key lives in the Secret `signing-secrets`. You do not need any storage backend beyond a registry.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1 |
| Namespace `tekton-chains` | Tekton Chains v0.29.9: the controller, an empty `signing-secrets` and an empty `chains-config` |
| `registry.localtest.me:5001` | An OCI registry inside the cluster, plain HTTP, lab-only |
| `deploy/workstation` in `workstation` | A pod with `cosign` 3.1.4, `regctl` 0.11.7, `curl` and `jq` |
| Namespace `starfleet` | Empty. Your Tasks and TaskRuns go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

The playground starts with no key and the default configuration. The first part sets up what you need.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
