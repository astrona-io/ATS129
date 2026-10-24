#!/usr/bin/env bash
# PASS when Prometheus has a scrape job named tekton-pipelines-controller
# whose target is up (up == 1).
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

value=""
for _ in $(seq 1 20); do
  value="$(prom_query 'up{job="tekton-pipelines-controller"}' '.data.result[0].value[1] // empty')"
  [ "$value" = "1" ] && break
  sleep 3
done
if [ "$value" != "1" ]; then
  health="$(prom_api /api/v1/targets '[.data.activeTargets[] | select(.labels.job=="tekton-pipelines-controller") | .scrapeUrl + " " + .health + " " + .lastError] | join("; ")')"
  echo "FAIL: Prometheus has no healthy target for the job tekton-pipelines-controller (up='${value}'; targets: ${health:-none})."
  exit 1
fi

echo "PASS: Prometheus scrapes the job tekton-pipelines-controller and the target is up."
exit 0
