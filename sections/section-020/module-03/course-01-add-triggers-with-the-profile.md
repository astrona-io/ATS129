# Add Triggers With The Profile

A profile is a named bundle of components. You choose it once in `spec.profile`, and the Operator creates one resource per component. This part reads the installation that the playground starts with, then adds Tekton Triggers by changing one word.

## What each profile installs

| Profile | Components |
| --- | --- |
| `lite` | Tekton Pipelines |
| `basic` | Tekton Pipelines, Tekton Triggers and Tekton Chains |
| `all` | The components of `basic` and the Tekton Dashboard |

The playground uses `lite`. Look at what the Operator created from it:

<!-- astrona:playground:renew -->

```sh
kubectl get tektonconfig,tektonpipelines
kubectl get tektontrigger.operator.tekton.dev
```

The first command lists the `TektonConfig` and a `TektonPipeline` resource. The second finds no `TektonTrigger`, because `lite` does not include Triggers. Each component resource has its own Ready condition, and the `TektonConfig` is Ready when all of its components are.

## Change the profile

Read the current spec, then change only the profile:

```sh
kubectl get tektonconfig config -o jsonpath='{.spec}'; echo
kubectl patch tektonconfig config --type merge -p '{"spec":{"profile":"basic"}}'
```

The Operator sees the new profile and creates a `TektonTrigger` resource named `trigger` (and a `TektonChain` resource, because `basic` also includes Chains). That resource creates installer sets, which create the Triggers Deployments in the target namespace. Wait for it:

```sh
kubectl wait tektonconfig/config --for=condition=Ready --timeout=600s
kubectl get tektontrigger.operator.tekton.dev
kubectl -n tekton-pipelines get deployments
```

The Deployment list now includes `tekton-triggers-controller`, `tekton-triggers-webhook` and `tekton-triggers-core-interceptors`. The Triggers controller turns events into runs, the webhook validates and defaults Triggers objects, and the core interceptors run the built-in filters.

## Why the profile is the right switch

You can create a `TektonTrigger` resource yourself, but the Operator owns it: it is created and removed from the profile, and settings you put on it are overwritten from the `TektonConfig`. Changing the profile is the only change that survives. Moving from `basic` back to `lite` removes Triggers and Chains again, so check that no EventListener is still in use before you do.

## Triggers objects you can now create

Once the webhook runs, the Triggers custom resources exist: `EventListener`, `TriggerBinding`, `TriggerTemplate`, `Trigger` and `Interceptor`. List them:

```sh
kubectl api-resources --api-group=triggers.tekton.dev
```

Their design is outside this module. What matters here is who runs them: an EventListener runs as a service account, and the next part sets the default for that.

## What to remember

- `lite` is Pipelines only, `basic` adds Triggers and Chains, `all` adds the Dashboard.
- Change the profile in the `TektonConfig`; the Operator creates and owns the `TektonTrigger`.
- Wait for the `TektonConfig` to be Ready before you test.
