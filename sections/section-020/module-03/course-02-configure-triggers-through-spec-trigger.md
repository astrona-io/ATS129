# Configure Triggers Through spec.trigger

Triggers has its own settings, separate from Pipelines. They live under `spec.trigger` in the `TektonConfig`, and the Operator writes them into ConfigMaps that the Triggers Deployments read. This part sets two of them and follows each value to its ConfigMap.

## The two properties

- `default-service-account` names the service account that an EventListener runs as when its own spec does not name one. The service account must exist in the namespace of the EventListener.
- `enable-api-fields` decides which Triggers API fields are accepted. The value `stable` is the default; `alpha` also enables fields that may change between releases.

Check that the profile is `basic` first. Then read the ConfigMaps before you change anything:

<!-- astrona:playground:renew -->

```sh
kubectl -n tekton-pipelines get configmap | grep triggers
kubectl -n tekton-pipelines get configmap feature-flags-triggers -o jsonpath='{.data.enable-api-fields}'; echo
kubectl -n tekton-pipelines get configmap config-defaults-triggers -o jsonpath='{.data}'; echo
```

If the lines are missing, Triggers is not installed yet: change the profile to `basic` and wait for the `TektonConfig` to be Ready.

## Set them in the TektonConfig

Create a service account for the default and set both properties:

```sh
kubectl create serviceaccount triggers-sa -n starfleet
kubectl patch tektonconfig config --type merge -p '{"spec":{"trigger":{"enable-api-fields":"alpha","default-service-account":"triggers-sa"}}}'
kubectl wait tektonconfig/config --for=condition=Ready --timeout=600s
```

The Operator rewrites the ConfigMaps. Read them again:

```sh
kubectl -n tekton-pipelines get configmap feature-flags-triggers -o jsonpath='{.data.enable-api-fields}'; echo
kubectl -n tekton-pipelines get configmap config-defaults-triggers -o jsonpath='{.data.default-service-account}'; echo
```

The values are `alpha` and `triggers-sa`. The mapping is direct: `spec.trigger.enable-api-fields` goes to `feature-flags-triggers`, and `spec.trigger.default-service-account` goes to `config-defaults-triggers`.

## A hand edit does not stay

Change one ConfigMap by hand and watch:

```sh
kubectl -n tekton-pipelines patch configmap config-defaults-triggers --type merge -p '{"data":{"default-service-account":"other"}}'
kubectl -n tekton-pipelines get configmap config-defaults-triggers -o jsonpath='{.data.default-service-account}'; echo
```

After a short time the Operator reconciles and writes `triggers-sa` back, because the `TektonConfig` is the source. If you need a key that has no field in `spec.trigger`, the same `options.configMaps` mechanism that Pipelines uses applies to the Triggers section: put the key under the ConfigMap name in the options block of the trigger spec.

## Check that a setting takes effect

A ConfigMap value is only a request. Check the Deployment: the Triggers controller reads its ConfigMaps at start and also watches them, and the Operator restarts a component when a change needs it. Look at the pods and the Ready condition after each change:

```sh
kubectl -n tekton-pipelines get pods | grep triggers
kubectl get tektontrigger.operator.tekton.dev trigger -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'; echo
```

## What to remember

- Triggers settings live in `spec.trigger`, not in `spec.pipeline`.
- `default-service-account` goes to `config-defaults-triggers`; `enable-api-fields` goes to `feature-flags-triggers`.
- The Operator overwrites hand edits; change the `TektonConfig`.

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-129-lab-020-03
astrona start ats-129-playground-020-03
```
