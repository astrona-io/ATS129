# Choose Profiles And Components

Before you can tune a component, you need to know which components exist in the cluster and why. The Tekton Operator decides that from one field, `spec.profile`. A wrong profile leaves out a component the team needs, or installs ones that use memory on a small cluster. This part shows what each profile installs, switches the profile, and shows how to prove from the cluster what the Operator did.

## What a profile is

A profile is a named set of components. The Operator installs the components of the profile and removes the ones it no longer lists. Three profiles exist:

| Profile | Components |
| --- | --- |
| `lite` | Tekton Pipelines |
| `basic` | Tekton Pipelines, Tekton Triggers and Tekton Chains |
| `all` | The components of `basic` and the Tekton Dashboard on Kubernetes |

Do not trust a table, including this one, for your version. Check what the Operator did: each component has its own custom resource kind, and the kind exists only while the component is installed. Look at the state of the playground:

<!-- astrona:playground:renew -->

```sh
kubectl get tektonconfig config -o jsonpath='{.spec.profile}{"\n"}'
kubectl get tektonconfig,tektonpipelines,tektontriggers,tektonchains,tektondashboards
```

The profile prints `lite`. The second command lists the `TektonConfig` and the `TektonPipeline`, and reports "No resources found" for the other kinds. The kinds exist because the Operator registered them with its own installation, but nothing has created an object of them.

## The resources the Operator creates

For every component in the profile, the Operator creates one custom resource that carries the component's settings. The resource has a fixed name: `pipeline` for `TektonPipeline`, `trigger` for `TektonTrigger`, `chain` for `TektonChain`, and `dashboard` for `TektonDashboard`. The `TektonConfig` owns them. If you delete one by hand, the Operator creates it again, and if you edit one by hand, the Operator writes the `TektonConfig` value back.

Each component resource has its own `Ready` condition, and the `TektonConfig` is `Ready` only when all of them are.

## Change the profile

Save this as `tektonconfig-config.yaml`. It changes only the profile:

```yaml
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  name: config
spec:
  profile: basic
  targetNamespace: tekton-pipelines
  pipeline:
    enable-api-fields: beta
```

Apply it:

```sh
kubectl apply -f tektonconfig-config.yaml
```

Then follow the Operator while it works. It pulls images and starts the new components, which takes a few minutes:

```sh
kubectl get tektonconfig config
kubectl wait tektonconfig/config --for=condition=Ready --timeout=900s
kubectl get tektonconfig,tektonpipelines,tektontriggers,tektonchains,tektondashboards
```

While components start, the `READY` column of the `TektonConfig` is `False` and `REASON` names what the Operator waits for. After the wait, `TektonTrigger` and `TektonChain` objects exist, and the dashboard kind still lists nothing. The namespaces tell the same story:

```sh
kubectl get pods -n tekton-pipelines
kubectl get namespace | grep tekton
```

The Triggers pods run in `tekton-pipelines`, and the Chains controller runs in its own namespace, `tekton-chains`, because the Chains release manifest puts it there. The `targetNamespace` field decides where the other components are installed, not where Chains runs.

## Go back to a smaller profile

Change `profile: basic` back to `profile: lite` in the file and apply it again:

```sh
kubectl apply -f tektonconfig-config.yaml
kubectl get tektonchains,tektontriggers
```

The Operator removes the component resources that the profile no longer lists, and with them the Deployments they installed. This is the safe way to remove a component. Deleting a Deployment by hand only makes the Operator create it again.

A profile is a starting set, not a lock. A component block in the `TektonConfig`, such as `spec.chain`, also exists when the profile does not install the component, but it has no effect until the component is installed.

You can now choose a profile, apply it, and prove from the cluster which components it installed. The Pipelines component is the one every profile installs. The open question is how to change its behaviour without touching its ConfigMaps.

## Common pitfalls

> [!WARNING]
> - **Judging the installation from a table.** Read the component resources in the cluster, because the profiles and versions change between Operator releases.
> - **Deleting a Deployment to remove a component.** The Operator creates it again; change the profile.
> - **Waiting too briefly.** Pulling images takes minutes; `kubectl wait` with a long timeout beats polling.
> - **Looking for Chains in `tekton-pipelines`.** The Chains controller runs in `tekton-chains`.
> - **Using the profile `all` on a small cluster.** It needs more memory than `lite`.
