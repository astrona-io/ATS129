# Question

Solve this question on: `terminal`

**Time:** about 40 minutes · **Topic:** Supply chain security

## Scenario

The `starfleet` team signs every release with one long-lived release key. Its public key is in the ConfigMap `release-key` in `starfleet`, and customers verify releases with it. Since a rebuild of the cluster, the TaskRun `release-shuttle` succeeds and even carries `chains.tekton.dev/signed: "true"`, but `cosign verify` finds nothing for `registry.localtest.me:5001/starfleet/shuttle:2.0.0`. The key's password was saved in the Secret `release-key-escrow` in `starfleet` before the rebuild.

## Your task

1. Find out why Tekton Chains signs nothing. Use the Chains controller log, the results of `release-shuttle` and `cosign` in the workstation pod. There is more than one fault, and the next one shows only after the first is fixed.
2. Fix every fault, in `tekton-chains` and in the Task `release-image`.
3. Leave a TaskRun named `release-shuttle` that released `registry.localtest.me:5001/starfleet/shuttle:2.0.0`, signed and attested with the release key.

## Constraints

- Keep the release key pair in `signing-secrets`. Do not generate a new key pair.
- Keep `chains-config` on SLSA v1.0 provenance (`slsa/v2alpha4`) stored in the OCI registry, with `transparency.enabled: "false"`.
- Keep the Task name `release-image`, its parameters and its step; change only what the fault needs.
- `release-shuttle` must use `taskRef` to `release-image` with `image` = `registry.localtest.me:5001/starfleet/shuttle` and `tag` = `2.0.0`.

## Done when

- `signing-secrets` holds the release key, with the `cosign.password` that decrypts it.
- `chains-config` has `artifacts.taskrun.format: slsa/v2alpha4`, `artifacts.taskrun.storage` with `oci`, `artifacts.oci.storage: oci`, `transparency.enabled: "false"` and `storage.oci.repository.insecure: "true"`.
- `release-shuttle` succeeded, reports `IMAGE_DIGEST` as `sha256:<digest>`, and carries `chains.tekton.dev/signed: "true"`.
- `cosign verify` and `cosign verify-attestation --type slsaprovenance1` pass for its image with the release public key.
- A new TaskRun of `release-image` started by the grader is signed and attested with the release key.
