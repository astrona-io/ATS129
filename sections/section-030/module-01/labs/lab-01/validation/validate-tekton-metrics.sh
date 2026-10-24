#!/usr/bin/env bash
# PASS when Prometheus holds real Tekton metrics from that job: the gauge
# tekton_pipelines_controller_running_taskruns with job="tekton-pipelines-controller".
set -uo pipefail

# prom_query QUERY FILTER: runs a PromQL instant query from the client pod
# and prints the result of the jq FILTER.
prom_query() {
  kubectl -n monitoring exec deploy/client -- env QUERY="$1" FILTER="$2" sh -c \
    'curl -fsS -G http://prometheus.monitoring:9090/api/v1/query --data-urlencode "query=$QUERY" | jq -r "$FILTER"' 2>/dev/null
}

# prom_api PATH FILTER: reads a Prometheus API path from the client pod and
# prints the result of the jq FILTER.
prom_api() {
  kubectl -n monitoring exec deploy/client -- env API_PATH="$1" FILTER="$2" sh -c \
    'curl -fsS "http://prometheus.monitoring:9090$API_PATH" | jq -r "$FILTER"' 2>/dev/null
}

count=""
for _ in $(seq 1 20); do
  count="$(prom_query 'tekton_pipelines_controller_running_taskruns{job="tekton-pipelines-controller"}' '.data.result | length')"
  [ -n "$count" ] && [ "$count" -ge 1 ] 2>/dev/null && break
  sleep 3
done
if [ -z "$count" ] || ! [ "$count" -ge 1 ] 2>/dev/null; then
  echo "FAIL: Prometheus has no tekton_pipelines_controller_running_taskruns series from the job tekton-pipelines-controller. Scrape the metrics port of the controller."
  exit 1
fi

echo "PASS: Prometheus stores the Tekton controller metrics."
exit 0
