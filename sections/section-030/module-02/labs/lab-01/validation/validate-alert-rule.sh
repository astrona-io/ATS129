#!/usr/bin/env bash
# PASS when Prometheus has loaded an alerting rule
# TektonTooManyRunningTaskRuns with the label severity=warning, a for time of
# 60 seconds, and a query that compares
# tekton_pipelines_controller_running_taskruns with 2.
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

rule="$(prom_api /api/v1/rules '[.data.groups[].rules[] | select(.type=="alerting" and .name=="TektonTooManyRunningTaskRuns")][0] // empty | (.query + "|" + (.labels.severity // "") + "|" + ((.duration // 0) | tostring))')"
if [ -z "$rule" ]; then
  echo "FAIL: Prometheus has no alerting rule named TektonTooManyRunningTaskRuns. Add it to tekton-rules.yml and restart Prometheus."
  exit 1
fi
duration="${rule##*|}"
rest="${rule%|*}"
severity="${rest##*|}"
query="${rest%|*}"
compact="${query// /}"
if [[ "$compact" != *tekton_pipelines_controller_running_taskruns* ]] || [[ "$compact" != *">2"* ]]; then
  echo "FAIL: TektonTooManyRunningTaskRuns must test tekton_pipelines_controller_running_taskruns > 2 (found: $query)."
  exit 1
fi
if [ "$severity" != "warning" ]; then
  echo "FAIL: TektonTooManyRunningTaskRuns must carry the label severity=warning (found '$severity')."
  exit 1
fi
if [ "${duration%.*}" != "60" ]; then
  echo "FAIL: TektonTooManyRunningTaskRuns must have for: 1m (the API reports a duration of ${duration} seconds)."
  exit 1
fi

echo "PASS: the alerting rule TektonTooManyRunningTaskRuns is loaded with the right query, for time and label."
exit 0
