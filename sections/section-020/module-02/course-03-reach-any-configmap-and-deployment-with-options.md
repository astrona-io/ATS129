# Reach Any ConfigMap And Deployment With Options

Some ConfigMap keys have no field in `spec.pipeline`, such as the log level in `config-logging`. Some settings are not in a ConfigMap at all, such as the replica count of a Deployment. The `options` block of a component covers both, so the Operator owns every setting and nobody has a reason to edit a resource by hand.

## The options block

`spec.pipeline.options` has two maps that matter here, and each one applies to a different kind of object:

| Key | What it changes |
| --- | --- |
| `options.configMaps.<name>.data` | Keys in the ConfigMap with that name |
| `options.deployments.<name>.spec` | The Deployment with that name, as a patch of its spec |

The Operator takes the ConfigMap it would write anyway, merges the keys you list into `data`, and writes the result. Keys you do not list keep the value the Operator chose.

## Set a log level

The controller reads `config-logging` for its level. The key is `loglevel.controller` and its default is `info`. A key with a dot in its name is written as a normal map key in YAML. Save this as `tektonconfig-options.yaml`:

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

Apply it, wait, and read the key. The dot must be escaped in jsonpath:

```sh
kubectl apply -f tektonconfig-options.yaml
kubectl wait tektonconfig/config --for=condition=Ready --timeout=300s
kubectl get configmap config-logging -n tekton-pipelines -o jsonpath='{.data.loglevel\.controller}{"\n"}'
```

It prints `debug`. The controller reads the logging ConfigMap with a watcher, so the level changes without a restart. Look for the proof in the logs, where debug lines now appear:

```sh
kubectl logs deploy/tekton-pipelines-controller -n tekton-pipelines --tail=5
```

Do not leave `debug` on in production. It writes a line for every reconcile and fills the log storage.

## Change a Deployment

A Deployment patch goes under the Deployment name. This one sets two replicas for the controller and adds a resource limit. Add it next to `configMaps`:

```yaml
    options:
      deployments:
        tekton-pipelines-controller:
          spec:
            replicas: 2
```

The Operator applies the patch to the Deployment it manages. Check the result with `kubectl get deploy tekton-pipelines-controller -n tekton-pipelines`. Running more than one controller replica needs the controller to run with leader election and buckets, which Tekton supports through the `config-leader-election` ConfigMap and the `--threadiness` setting. Raising the replicas alone is not a complete scaling plan, so read the Tekton documentation on high availability before you do it in a real cluster.

## Place pods with spec.config

Settings that apply to every Deployment of the installation sit in `spec.config`, outside `spec.pipeline`:

```yaml
spec:
  config:
    nodeSelector:
      kubernetes.io/os: linux
    tolerations:
      - key: dedicated
        operator: Equal
        value: ci
        effect: NoSchedule
```

The Operator copies the node selector and the tolerations into the pod templates of the Deployments of all components. Use it when the control plane of Tekton must run on dedicated nodes.

## Which place for which setting

Follow this order when you need to change a setting:

1. A field in `spec.pipeline`: use it. It is the shortest form, and it is documented.
2. A key in a ConfigMap without a field: use `options.configMaps`.
3. A field of a Deployment: use `options.deployments`.
4. A setting for all components' pods: use `spec.config`.

A mistake in an `options` key name is not rejected. The Operator writes an unknown key into the ConfigMap, and the component ignores it. After every change, read the ConfigMap back, as the commands above do.

## Mission

Apply what you learned in a real task. The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-129-playground-020-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-020/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-129-lab-020-02
astrona start ats-129-playground-020-02
```

## Common pitfalls

> [!WARNING]
> - **Writing a dotted key as a nested map.** `loglevel.controller` is one key with a dot, not `loglevel` with a child.
> - **Forgetting the escape in jsonpath.** Read it as `{.data.loglevel\.controller}`.
> - **Trusting an unchecked key name.** An unknown key is written and ignored. Read the result.
> - **Scaling by replicas alone.** Check leader election and the Tekton high availability guidance first.
> - **Leaving debug logs on.** They fill storage.
