# Solution: Add And Configure Tekton Triggers Through The TektonConfig

Work the task yourself first. Running `astrona submit -c sections/section-020/module-03/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the `TektonConfig` holds the profile and the two Triggers properties and keeps the rest; the Triggers ConfigMaps carry the new values; and Triggers is installed and `Ready`.

## Step 1: Read the current TektonConfig

```sh
kubectl get tektonconfig config -o yaml
kubectl get tektontrigger.operator.tekton.dev
```

The `spec` holds `profile: lite`, `targetNamespace: tekton-pipelines` and `pipeline.enable-api-fields: beta`. There is no `TektonTrigger` yet, because `lite` installs Pipelines only.

## Step 2: Write the new TektonConfig

The profile `basic` adds Tekton Triggers and Tekton Chains. The Triggers settings are fields of `spec.trigger`. Save this as `tektonconfig-config.yaml`:

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
  trigger:
    enable-api-fields: alpha
    default-service-account: triggers-sa
```

```sh
kubectl apply -f tektonconfig-config.yaml
```

## Step 3: Wait for the Operator

The Operator creates a `TektonTrigger` resource and installs the Triggers Deployments. Wait until everything is `Ready`:

```sh
kubectl wait tektonconfig/config --for=condition=Ready --timeout=600s
kubectl get tektontrigger.operator.tekton.dev
kubectl -n tekton-pipelines get deployments
```

The list now includes `tekton-triggers-controller`, `tekton-triggers-webhook` and `tekton-triggers-core-interceptors`.

## Step 4: Read the Triggers ConfigMaps

```sh
kubectl -n tekton-pipelines get configmap feature-flags-triggers -o jsonpath='{.data.enable-api-fields}'; echo
kubectl -n tekton-pipelines get configmap config-defaults-triggers -o jsonpath='{.data.default-service-account}'; echo
```

The commands print `alpha` and `triggers-sa`. The Operator wrote both from `spec.trigger`, and it puts them back if you edit the ConfigMaps by hand.
