#!/usr/bin/env bash
# PASS when Prometheus has loaded a recording rule named
# tekton:taskrun_failed:ratio whose query divides failed TaskRuns by all
# TaskRuns, and the recorded series has a value between 0 and 1.
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

rule="$(prom_api /api/v1/rules '[.data.groups[].rules[] | select(.type=="recording" and .name=="tekton:taskrun_failed:ratio")][0] // empty | .query')"
if [ -z "$rule" ]; then
  echo "FAIL: Prometheus has no recording rule named tekton:taskrun_failed:ratio. Add it to tekton-rules.yml and restart Prometheus."
  exit 1
fi
if [[ "$rule" != *tekton_pipelines_controller_taskrun_total* ]] || [[ "$rule" != *'status="failed"'* ]] || [[ "$rule" != */* ]]; then
  echo "FAIL: the recording rule must divide failed TaskRuns (status=\"failed\") by all TaskRuns of tekton_pipelines_controller_taskrun_total (found: $rule)."
  exit 1
fi

value=""
for _ in $(seq 1 30); do
  value="$(prom_query 'tekton:taskrun_failed:ratio' '.data.result[0].value[1] // empty')"
  [ -n "$value" ] && break
  sleep 3
done
if [ -z "$value" ]; then
  echo "FAIL: Prometheus has not recorded any value for tekton:taskrun_failed:ratio yet."
  exit 1
fi
if ! awk -v v="$value" 'BEGIN { exit !(v > 0 && v <= 1) }'; then
  echo "FAIL: tekton:taskrun_failed:ratio is '$value'; with one failed run among the TaskRuns it must be above 0 and at most 1."
  exit 1
fi

echo "PASS: the recording rule tekton:taskrun_failed:ratio is loaded and records ${value}."
exit 0
