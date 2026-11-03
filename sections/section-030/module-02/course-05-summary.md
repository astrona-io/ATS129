# Summary

A working scrape job and one alert are the start of monitoring Tekton, not the end. Each component needs its own job, heavy queries belong in recording rules, alerts must cover runs that are stuck or slow and not only runs that failed, and the number of series must stay within what the monitoring server can hold.

## What you learned

Every Tekton component serves metrics on a port named for metrics, usually `9090`: the Pipelines controller, the webhook, the events controller, the Pruner and the Chains controller. The API server proxy reads each endpoint without any monitoring system, which shows the metric names of the installed version. One scrape job per component gives each series a `job` label that queries and alerts can select.

A recording rule has the key `record` and stores the result of a query as a new series on every evaluation. By convention its name is `level:metric:operations`, and the colon marks it as recorded. A recording rule over a missing metric stores nothing and reports no error, so the recorded series has to be read back. An alerting rule on a gauge such as `tekton_pipelines_controller_running_taskruns` compares it with a number, and a `for` time keeps one short spike from becoming a page. A `histogram_quantile` over the duration buckets reports slow runs after they end. When a metric disappears, a value alert cannot fire, so an alert on `up` or on `absent` completes the set.

The series count decides the cost of the monitoring server. The run metric levels `taskrun` and `pipelinerun` create a full set of series for every run, and the controller applies a change only after a restart. `metric_relabel_configs` with `action: drop` removes series after the scrape, and retention limits the age or the size of what stays on disk. The key facts to remember are these:

- One scrape job per Tekton component, and the metrics port, never the probes or profiling port.
- Recorded series use colons in their names; read a recorded series back to prove the rule works.
- Alert on running runs with a `for` time, on slow runs with `histogram_quantile`, and on missing metrics with `absent`.
- Keep `metrics.taskrun.level` and `metrics.pipelinerun.level` at their defaults, and drop unused series with `metric_relabel_configs`.

<!-- astrona:playground:destroy -->
