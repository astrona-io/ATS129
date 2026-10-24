# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Supply chain security

## Scenario

The `starfleet` team builds its images with the Task `build-image`, which pushes them to the registry `registry.localtest.me:5001`. Tekton Chains v0.29.9 is installed, and the TaskRun `build-bridge` even carries the annotation `chains.tekton.dev/signed: "true"`. Yet the release team finds no signature and no provenance for the image `registry.localtest.me:5001/starfleet/bridge:1.0.0`, and refuses to ship it.

## Your task

1. Give Tekton Chains a signing key: a cosign key pair in the Secret `signing-secrets` in the namespace `tekton-chains`. Use `cosign` in the workstation pod.
2. Configure Tekton Chains in the ConfigMap `chains-config`:
   - TaskRun provenance in the SLSA v1.0 format `slsa/v2alpha4`,
   - TaskRun attestations stored in the OCI registry, next to the image,
   - image signatures stored in the OCI registry,
   - no upload to a transparency log,
   - plain-HTTP access allowed for the lab registry.
3. Fix the Task `build-image` so that Chains can tell which image a TaskRun built.
4. Leave a TaskRun named `build-bridge` that built `registry.localtest.me:5001/starfleet/bridge:1.0.0` and whose image is signed and attested.

## Constraints

- Keep the Task name `build-image`, its parameters `image` and `tag`, and its step. Only the results and the lines that write them may change.
- `build-bridge` must use `taskRef` to `build-image` with `image` = `registry.localtest.me:5001/starfleet/bridge` and `tag` = `1.0.0`.
- Do not use a public transparency log or a public certificate authority. The lab signs with a key pair.

## Done when

- `signing-secrets` holds `cosign.key` (an encrypted cosign private key), `cosign.password` and `cosign.pub`.
- `chains-config` has `artifacts.taskrun.format: slsa/v2alpha4`, `artifacts.taskrun.storage` that includes `oci`, `artifacts.oci.storage: oci`, `transparency.enabled: "false"` and `storage.oci.repository.insecure: "true"`.
- `build-bridge` succeeded, reports the results `IMAGE_URL` and `IMAGE_DIGEST`, and carries `chains.tekton.dev/signed: "true"`.
- `cosign verify` and `cosign verify-attestation --type slsaprovenance1` both pass for the image of `build-bridge` with `cosign.pub` from `signing-secrets`.
- A new TaskRun of `build-image` started by the grader is signed and attested the same way.
