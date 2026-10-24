#!/usr/bin/env bash
# PASS when Prometheus has loaded an alerting rule TektonTaskRunFailed with
# the label severity=warning, whose query uses
# tekton_pipelines_controller_taskrun_total with status="failed".
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

rule="$(prom_api /api/v1/rules '[.data.groups[].rules[] | select(.type=="alerting" and .name=="TektonTaskRunFailed")][0] // empty | .query + "|" + (.labels.severity // "")')"
if [ -z "$rule" ]; then
  echo "FAIL: Prometheus has no alerting rule named TektonTaskRunFailed. Add it to tekton-rules.yml and restart Prometheus."
  exit 1
fi
query="${rule%|*}"
severity="${rule##*|}"
if [[ "$query" != *tekton_pipelines_controller_taskrun_total* ]] || [[ "$query" != *'status="failed"'* ]]; then
  echo "FAIL: TektonTaskRunFailed must use tekton_pipelines_controller_taskrun_total with status=\"failed\" (found: $query)."
  exit 1
fi
if [ "$severity" != "warning" ]; then
  echo "FAIL: TektonTaskRunFailed must carry the label severity=warning (found '$severity')."
  exit 1
fi

echo "PASS: the alerting rule TektonTaskRunFailed is loaded with the right query and label."
exit 0
