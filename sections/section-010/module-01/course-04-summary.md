# Summary

Tekton Chains turns every finished TaskRun and PipelineRun into signed supply-chain evidence. It needs no change to the Tasks beyond the names of their results, and it never slows down or fails a build.

## What you learned

Chains is one controller in the namespace `tekton-chains`, installed from its own release manifest. When a run ends, the controller formats a payload, signs it, stores the payload and the signature, and writes the annotation `chains.tekton.dev/signed` on the run. Because all of this happens after the run, a signing problem never changes the run's status. The annotation can even say `true` when Chains had no signer or found no image, so the only real proof is a check with `cosign` against the storage.

The signing key lives in the Secret `signing-secrets`. A cosign key pair has three keys there: `cosign.key`, `cosign.password` and `cosign.pub`, and `cosign generate-key-pair k8s://tekton-chains/signing-secrets` writes them and makes the Secret immutable. Everything else lives in the ConfigMap `chains-config`. The format keys choose the provenance version: `in-toto` and `slsa/v1` write SLSA v0.2, `slsa/v2alpha3` and `slsa/v2alpha4` write SLSA v1.0. The storage keys choose where it goes: `tekton` puts it on the run as annotations, `oci` puts it in the registry next to the image.

Chains finds the image a run built through type hinting: results whose names end in `IMAGE_URL` and `IMAGE_DIGEST`, the `IMAGES` result, or object results ending in `ARTIFACT_OUTPUTS`. In the registry, the classic layout puts the image signature in a `.sig` tag and the attestation in a `.att` tag, both named after the digest. `cosign verify` checks the signature, and `cosign verify-attestation --type slsaprovenance1` checks a SLSA v1.0 attestation.

Long-lived keys have alternatives. Keyless signing gets a short-lived certificate from Fulcio for the controller's OIDC identity, and the Rekor transparency log records every signature in public. A KMS signer keeps the private key inside a key management service. The key facts to remember are these:

- Chains works after the run and never blocks it; check signatures with `cosign`, not with the annotation.
- No signer or no type-hinted image still gives `signed: "true"`; a failed push gives `retries` and then `signed: "failed"`.
- Chains handles each run once; after a fix, start a new run.
- `storage.oci.repository.insecure: "true"` is for test registries only.

<!-- astrona:playground:destroy -->
