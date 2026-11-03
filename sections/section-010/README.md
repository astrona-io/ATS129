# Section 010: Sign And Attest Builds With Tekton Chains

A container image in a registry says nothing about where it came from. Anyone with push rights could have built it, from any source, on any machine. Software supply chain security closes that gap: every artifact gets a signature that proves who published it and a signed record that says how it was built. Tekton Chains adds both to Tekton, without changing a single Task.

This section shows Tekton Chains at work. You first see how Chains watches finished TaskRuns, give it a signing key and read the provenance it writes. Then you let a Task tell Chains which image it built, so Chains signs the image and pushes a SLSA provenance attestation next to it in an OCI registry. Last, you look at keyless signing with Fulcio and Rekor, the transparency log, and the ways a signing setup fails quietly.

**Topic covered:** Supply chain security

## What you will learn

- What Tekton Chains does after a TaskRun or PipelineRun ends: format, sign, store, and annotate.
- Why Chains never blocks or fails a run, and why `chains.tekton.dev/signed: "true"` alone proves nothing.
- Giving Chains a cosign key pair in the Secret `signing-secrets`.
- Configuring `chains-config`: payload formats (`in-toto`, `slsa/v1`, `slsa/v2alpha3`, `slsa/v2alpha4`), storage backends (`tekton`, `oci` and others), signers and the transparency log.
- Type hinting with the results `IMAGE_URL` and `IMAGE_DIGEST` (and `ARTIFACT_OUTPUTS`), so Chains knows which image a run built.
- Storing signatures and attestations in an OCI registry, including a plain-HTTP lab registry.
- Verifying with `cosign verify` and `cosign verify-attestation`.
- Keyless signing with Fulcio, uploads to the Rekor transparency log, and KMS signers.
- The four TaskRun provenance formats, the SLSA version of each, and the fields of a v0.2 and a v1.0 statement.
- Storage as a list: the `tekton` annotations, the `oci` attestation, `storage.oci.repository`, and the keys of `gcs`, `docdb`, `grafeas` and `archivista`.
- PipelineRun provenance, deep inspection, and the three artifact prefixes.
- The `x509` and `kms` signers, key rotation, and checking a payload without the cluster.

## The learning path

The section has two modules. Each has a landing page, short parts, a graded lab right after the part it tests, a summary and a knowledge check. Each module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Signed Provenance With Tekton Chains

The module starts at its landing page, which also launches the playground. The playground runs Tekton Pipelines v1.17.1, Tekton Chains v0.29.9 with no key yet, an in-cluster OCI registry and a workstation pod with `cosign` and `regctl`.

1. How Tekton Chains Works
2. Sign Images And Store Attestations In A Registry
3. Keyless Signing, Transparency Logs And Quiet Failures, followed by the lab **Sign Built Images With Tekton Chains**
4. Summary

### 2. Provenance Formats, Storage Backends And Signers

The second module goes deeper. The playground starts with Tekton Pipelines v1.17.1, Tekton Chains v0.29.9 with no key yet, the in-cluster registry and the workstation pod, as in module 1. The first part sets up a key and a Task.

1. Pick A Provenance Format
2. Choose Where Chains Stores Provenance, followed by the lab **Choose Chains Provenance Format And Storage**
3. Provenance For PipelineRuns And Images
4. Signers, Keys And Offline Verification
5. Summary

## Section capstone: Repair A Broken Signing Setup

The capstone is one graded scenario that combines the whole module. The release TaskRun of the `starfleet` team carries `chains.tekton.dev/signed: "true"`, yet no signature exists. Three faults hide behind each other: a key that Chains cannot open, a digest result that Chains cannot read, and a registry that Chains cannot reach. Find each one from the controller log and the registry, fix it without replacing the release key, and prove the release with `cosign`. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-129-capstone-010
```
