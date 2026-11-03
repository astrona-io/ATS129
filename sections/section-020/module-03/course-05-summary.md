# Summary

The `TektonConfig` is the single source for every component the Operator installs, and the Operator release decides which component versions it installs. Adding a component and upgrading are therefore both changes to the Operator's inputs, not to the components themselves.

## What you learned

The profile selects the components: `lite` installs Pipelines, `basic` adds Triggers and Chains and `all` adds the Dashboard. Changing `spec.profile` to `basic` makes the Operator create a `TektonTrigger` resource and the Triggers Deployments. Triggers settings live in `spec.trigger`: `default-service-account` goes to the ConfigMap `config-defaults-triggers`, and `enable-api-fields` goes to `feature-flags-triggers`. A hand edit of these ConfigMaps is overwritten, so the `TektonConfig` is the only place to change them.

An Operator upgrade replaces all component versions at once. Read the release notes for removed fields and the order of releases, save the `TektonConfig` and keep Tekton definitions in version control, test on a cluster with the same profile, and apply the new release manifest. Afterwards wait for the Operator Deployments, then for the `TektonConfig` to be Ready; read conditions, the Operator log and the installer sets when it is not. Prove the result with a real run, and plan the way back as a restore, not as a downgrade. The key facts to remember are these:

- Profile `basic` adds Triggers (and Chains); `spec.trigger` configures it.
- Triggers ConfigMaps are `config-defaults-triggers` and `feature-flags-triggers`.
- The Operator version sets the component versions; read the release notes first.
- Check Ready conditions and a real run after an upgrade.

<!-- astrona:playground:destroy -->
