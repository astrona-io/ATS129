# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Supply chain security

## Scenario

The `starfleet` team signs its images with Tekton Chains v0.29.9. The image `registry.localtest.me:5001/starfleet/bridge:1.0.0` has a signature in the registry, and the TaskRun `build-bridge` carries a provenance statement in its annotations. The audit team now asks for two changes. The provenance must use the SLSA v1.0 format, and it must also be stored in the registry next to the image, so that auditors can verify it with `cosign` without access to the cluster. The signing key, the registry settings and the Task `build-image` already work.

## Your task

1. Configure Tekton Chains in the ConfigMap `chains-config` so that TaskRun provenance:
   - uses the SLSA v1.0 format `slsa/v2alpha4`,
   - is stored both in the TaskRun annotations and in the OCI registry.
2. Leave a TaskRun named `build-bridge` that Chains handled with the new settings.

## Constraints

- Keep the existing keys of `chains-config`: image signatures in the registry, no transparency log, plain HTTP for the lab registry.
- Do not change the signing key or the Task `build-image`.
- `build-bridge` must keep `taskRef` to `build-image` with `image` = `registry.localtest.me:5001/starfleet/bridge` and `tag` = `1.0.0`.

## Done when

- `chains-config` has `artifacts.taskrun.format: slsa/v2alpha4`, and `artifacts.taskrun.storage` includes both `tekton` and `oci`. The other keys are unchanged.
- `build-bridge` succeeded, carries `chains.tekton.dev/signed: "true"`, and holds a `payload-taskrun-<uid>` and a `signature-taskrun-<uid>` annotation whose payload is a SLSA v1.0 provenance statement.
- `cosign verify` and `cosign verify-attestation --type slsaprovenance1` both pass for the image of `build-bridge` with `cosign.pub` from `signing-secrets`.
- A new TaskRun of `build-image` started by the grader is signed and attested the same way.
