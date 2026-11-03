# Summary

`chains-config` is organised by artifact type. The prefixes `artifacts.taskrun.`, `artifacts.pipelinerun.` and `artifacts.oci.` each take the keys `format`, `storage` and `signer`, and a setting for one prefix never changes another.

The format is the shape of the statement. `in-toto` and its alias `slsa/v1` write SLSA v0.2 with the `predicateType` `https://slsa.dev/provenance/v0.2`. `slsa/v2alpha3` and `slsa/v2alpha4` write SLSA v1.0 with `https://slsa.dev/provenance/v1`, split into `buildDefinition` and `runDetails`. The keys `builder.id` and `builddefinition.buildtype` name the builder and the build type.

The storage is the place. It is a comma-separated list, and Chains writes the same signed statement to every backend. `tekton` stores annotations on the run, named `payload-taskrun-<uid>` and `signature-taskrun-<uid>`, and they disappear when the run is pruned. `oci` attaches an attestation to the image, and `storage.oci.repository` moves signatures and attestations to another repository. The backends `gcs`, `docdb`, `grafeas` and `archivista` need their own settings. PipelineRuns have their own provenance, and `artifacts.pipelinerun.enable-deep-inspection` includes the artifacts of child TaskRuns.

The signer is the key. `x509` uses the Secret `signing-secrets` or Fulcio, and `kms` uses a key in a key management service through `signers.kms.kmsref`. A rotation needs a new key, a restart of the controller and a published list of public keys, because Chains never re-signs old runs. The key facts to remember are these:

- Chains handles a run once, so create the run again to see a new setting.
- `slsa/v1` is SLSA v0.2; the SLSA v1.0 formats are `slsa/v2alpha3` and `slsa/v2alpha4`.
- Add `oci` to the storage list when auditors have no cluster access, and when runs are pruned.
- Verify with the matching `--type`: `slsaprovenance` for v0.2, `slsaprovenance1` for v1.0.

<!-- astrona:playground:destroy -->
