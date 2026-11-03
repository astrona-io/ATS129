# Solution: Tune Tekton Pipelines Through The TektonConfig

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the `TektonConfig` holds the three settings and keeps its profile and target namespace; the ConfigMaps carry the new values; and the installation is `Ready`.

## Step 1: Read the current TektonConfig

```sh
kubectl get tektonconfig config -o yaml
kubectl get configmap feature-flags config-defaults config-logging -n tekton-pipelines
```

The `spec` holds `profile: lite`, `targetNamespace: tekton-pipelines` and `pipeline.enable-api-fields: beta`. The three ConfigMaps exist in `tekton-pipelines`. The Operator wrote them from the `TektonConfig`, so a change made only in a ConfigMap does not stay.

## Step 2: Write the new TektonConfig

The first two settings are fields of `spec.pipeline`. The log level is a key in the ConfigMap `config-logging`, which has no field of its own, so it goes through `spec.pipeline.options.configMaps`. Save this as `tektonconfig-config.yaml`:

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
    options:
      configMaps:
        config-logging:
          data:
            loglevel.controller: debug
```

Apply it:

```sh
kubectl apply -f tektonconfig-config.yaml
```

## Step 3: Wait for the Operator

The Operator reconciles the change and updates the ConfigMaps:

```sh
kubectl wait tektonconfig/config --for=condition=Ready --timeout=600s
```

## Step 4: Check the ConfigMaps

```sh
kubectl get configmap feature-flags -n tekton-pipelines -o jsonpath='{.data.enable-api-fields}{"\n"}'
kubectl get configmap config-defaults -n tekton-pipelines -o jsonpath='{.data.default-timeout-minutes}{"\n"}'
kubectl get configmap config-logging -n tekton-pipelines -o jsonpath='{.data.loglevel\.controller}{"\n"}'
```

They print `stable`, `30` and `debug`. If one still shows the old value, wait a little and run the command again; the Operator updates the installer sets one after the other.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Edit the ConfigMaps with `kubectl edit` | The Operator owns them and writes the `TektonConfig` values back |
| Create a second `TektonConfig` | The Operator accepts only the one named `config` |
| Change `profile` to `all` | It installs more components than the task asks for, and the grader checks the profile |
| Put `loglevel.controller` directly under `spec.pipeline` | It is not a field of `spec.pipeline`; use `options.configMaps` |

## Common mistakes

- Writing `default-timeout-minutes: "30"` as a string. The field is a number.
- Indenting `options` under `pipeline` wrongly. It is a sibling of `enable-api-fields`.
- Checking the ConfigMaps before the Operator has reconciled. Wait for `Ready` first.
