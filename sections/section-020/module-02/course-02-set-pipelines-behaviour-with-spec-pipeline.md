# Set Pipelines Behaviour With spec.pipeline

The `spec.pipeline` block of the `TektonConfig` holds the settings that teams change most: which API fields are allowed, how long a run may take, and which service account a run uses. This part shows how a field in the block turns into a key in a ConfigMap, so that you can set a value and prove the Operator wrote it.

## From a field to a ConfigMap key

Tekton Pipelines reads its behaviour from ConfigMaps in `tekton-pipelines`. The ones you meet first are:

| ConfigMap | What it holds |
| --- | --- |
| `feature-flags` | Switches such as `enable-api-fields`, `await-sidecar-readiness` and `disable-affinity-assistant` |
| `config-defaults` | Defaults for runs, such as `default-timeout-minutes`, `default-service-account` and `default-pod-template` |
| `config-logging` | Log levels per component |
| `config-observability` | Metrics levels |

The Operator exposes many of these keys as fields of `spec.pipeline`. The field name is the ConfigMap key name, so `enable-api-fields` in the `TektonConfig` becomes `enable-api-fields` in `feature-flags`. Read the current state of a key in both places:

<!-- astrona:playground:renew -->

```sh
kubectl get tektonconfig config -o jsonpath='{.spec.pipeline.enable-api-fields}{"\n"}'
kubectl get configmap feature-flags -n tekton-pipelines -o jsonpath='{.data.enable-api-fields}{"\n"}'
```

Both print `beta` in the playground. The first command reads the request, the second the result. A key with a dash in its name is fine inside jsonpath for the `data` map, and this is the form to use.

## Change feature flags and defaults

Save this as `tektonconfig-pipeline.yaml`:

```yaml
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  name: config
spec:
  profile: lite
  targetNamespace: tekton-pipelines
  pipeline:
    enable-api-fields: stable
    default-timeout-minutes: 30
    await-sidecar-readiness: true
```

Apply it and wait until the Operator is done:

```sh
kubectl apply -f tektonconfig-pipeline.yaml
kubectl wait tektonconfig/config --for=condition=Ready --timeout=300s
```

Two things deserve a closer look. The first is that the file repeats `profile` and `targetNamespace`. A `kubectl apply` replaces the fields it manages, so a file that leaves them out can fail or change them. Always keep them in the file. The second is that `default-timeout-minutes` is a number, not a string. The Operator turns it into a string when it writes the ConfigMap.

Now read the results:

```sh
kubectl get configmap feature-flags -n tekton-pipelines -o jsonpath='{.data.enable-api-fields}{"\n"}'
kubectl get configmap config-defaults -n tekton-pipelines -o jsonpath='{.data.default-timeout-minutes}{"\n"}'
```

They print `stable` and `30`. If a command prints the old value, wait a few seconds and read again, because the Operator reconciles after the apply returns.

## What the flags change

`enable-api-fields` has three values. `stable` allows only the stable fields of the API. `beta` allows the stable and the beta fields, and `alpha` allows alpha fields on top. Setting `stable` rejects a Task that uses a beta field, so a team that sets it must know which fields its Tasks use. Setting it lower than what the Tasks need is a common cause of "unknown field" errors after a change.

`default-timeout-minutes` applies to a TaskRun or a PipelineRun that does not set its own `timeout`. A run with its own timeout keeps it. The value `0` means no timeout, which is rarely what a team wants.

## Prove a default works

Create a Task and a run without a timeout, and read the timeout the controller gave it:

```sh
cat <<'YAML' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: hello
  namespace: starfleet
spec:
  steps:
    - name: say
      image: busybox:1.36
      script: |
        echo hello
YAML
tkn task start hello -n starfleet --showlog
kubectl get taskrun -n starfleet -o jsonpath='{.items[0].spec.timeout}{"\n"}'
```

The run prints `30m0s`. The default was filled in when the run was created, so the value shows what applied at that moment, and a later change to the default does not rewrite old runs.

## What happens to a hand edit

Edit a key in the ConfigMap by hand and watch what happens:

```sh
kubectl patch configmap config-defaults -n tekton-pipelines --type merge -p '{"data":{"default-timeout-minutes":"5"}}'
sleep 20
kubectl get configmap config-defaults -n tekton-pipelines -o jsonpath='{.data.default-timeout-minutes}{"\n"}'
```

The Operator writes the value from the `TektonConfig` back, and the command prints `30`. The change is not kept, and nothing in the Operator logs is an error. This is the behaviour that surprises teams most. If a key has a field in `spec.pipeline`, the `TektonConfig` wins.

You can now set feature flags and defaults, and show that they arrive in the ConfigMaps. Not every ConfigMap key has a field in `spec.pipeline`. The next part covers the ones that do not.

## Common pitfalls

> [!WARNING]
> - **Editing the ConfigMap.** The Operator undoes the edit. Change the `TektonConfig`.
> - **Leaving out `profile` or `targetNamespace` in the file.** Keep both in every file you apply.
> - **Setting `stable` without checking the Tasks.** A Task that uses a beta field is rejected.
> - **Expecting old runs to change.** A default is copied into a run when it is created.
> - **Reading the ConfigMap right after the apply.** Wait for `Ready`, then read.
