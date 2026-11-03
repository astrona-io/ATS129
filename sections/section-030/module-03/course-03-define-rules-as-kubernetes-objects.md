# Define Rules As Kubernetes Objects

In the playground, Prometheus reads two files from one ConfigMap and you restart it to change them. Many clusters run the Prometheus Operator instead. It adds custom resources, so a scrape job or a rule is a Kubernetes object that any team can create in its own namespace. This part describes the two objects that matter for Tekton, ServiceMonitor and PrometheusRule. The playground does not install the Operator, so the YAML here is not applied; the examples show what you would apply in a cluster that has it. The commands that read the Tekton Service do run in the playground.

## What the Operator adds

The Operator runs a controller that watches custom resources of the group `monitoring.coreos.com`. The main ones are:

| Resource | It replaces |
| --- | --- |
| `Prometheus` | The Deployment or StatefulSet of the server and the file `prometheus.yml` |
| `ServiceMonitor` | One entry under `scrape_configs` that discovers targets from a Service |
| `PrometheusRule` | A rule file with recording and alerting groups |
| `Alertmanager` and `AlertmanagerConfig` | The Alertmanager server and parts of its routing |

The controller turns the objects into configuration, writes it to Secrets that the server reads, and asks the server to reload. No restart is needed when a ServiceMonitor or a PrometheusRule changes.

## A ServiceMonitor for the Pipelines controller

A ServiceMonitor selects Services by label and names the port to scrape. The Pipelines controller Service has a port named `http-metrics`:

<!-- astrona:playground:renew -->

```sh
kubectl get service tekton-pipelines-controller -n tekton-pipelines --show-labels
kubectl get service tekton-pipelines-controller -n tekton-pipelines -o jsonpath='{.spec.ports[*].name}'
```

Use the labels and the port name that the commands print. A ServiceMonitor has this shape:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tekton-pipelines-controller
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames: [tekton-pipelines]
  selector:
    matchLabels:
      app.kubernetes.io/name: controller      # replace with the labels printed above
  endpoints:
    - port: http-metrics
      interval: 15s
```

Three details decide whether it works. `selector.matchLabels` must match the labels of the Service, not of the Pods. `endpoints[].port` is the **name** of the Service port, not its number; `targetPort` and `port` are other fields. `namespaceSelector` is needed when the Service is in another namespace than the ServiceMonitor, which is the case for Tekton.

## Make the Prometheus object pick it up

A `Prometheus` object chooses which ServiceMonitors and PrometheusRules it uses with label selectors, `serviceMonitorSelector` and `ruleSelector`, and namespace selectors for each. An empty selector selects everything; a missing one selects nothing in some setups. In a cluster installed with a packaged chart, the selector often requires a label such as `release: <name>` on every object. The usual reason a new ServiceMonitor shows no target is that its labels do not match the selector of the Prometheus object, so read the selector first:

```sh
kubectl get prometheus -A -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.serviceMonitorSelector}{" "}{.spec.ruleSelector}{"\n"}{end}'
```

## A PrometheusRule for the same alert

A PrometheusRule holds groups with the same fields as the rule file in the playground. The alert you know becomes:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tekton-alerts
  namespace: monitoring
spec:
  groups:
    - name: tekton-alerts
      rules:
        - alert: TektonTooManyRunningTaskRuns
          expr: tekton_pipelines_controller_running_taskruns > 2
          for: 1m
          labels:
            severity: warning
```

The Operator validates the expressions when the object is created, so a typo in PromQL is rejected at `kubectl apply` and not found at 3 a.m. The labels `severity` stay the contract with Alertmanager: the route for warnings matches on them.

## Routing with AlertmanagerConfig

An `AlertmanagerConfig` object lets a team define routes and receivers in its own namespace. The Operator merges it into the main configuration and adds a matcher for the namespace, so a team can route only its own alerts. Its route fields follow the file format you read in the first part: `matchers`, `groupBy`, `groupWait`, `groupInterval` and `repeatInterval`, in camelCase.

## What to remember

- A ServiceMonitor is a scrape job as an object; a PrometheusRule is a rule file as an object.
- The `port` in a ServiceMonitor is the Service port name.
- A Prometheus object picks objects by label selectors; a missing label is the usual reason nothing happens.
- The labels on alerts, such as `severity`, work the same with and without the Operator.
