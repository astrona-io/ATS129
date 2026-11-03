#!/usr/bin/env bash
# PASS when the alert TektonTooManyRunningTaskRuns fires while the grader
# keeps three slow-check TaskRuns running, and Alertmanager routes it to the
# receiver platform-oncall. The alert has a for time of one minute, so the
# grader waits up to four minutes for the state firing and then for delivery.
set -uo pipefail

NS="starfleet"

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

names=()
cleanup() {
  for run in "${names[@]}"; do
    kubectl -n "$NS" delete taskrun "$run" --wait=false >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

for _ in 1 2 3; do
  name="$(kubectl create -f - -o jsonpath='{.metadata.name}' 2>/dev/null <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: slow-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  taskRef:
    name: slow-check
  params:
    - name: seconds
      value: "300"
YAML
)"
  if [ -z "$name" ]; then
    echo "FAIL: the grader could not create a TaskRun of slow-check."
    exit 1
  fi
  names+=("$name")
done

state=""
for _ in $(seq 1 80); do
  state="$(prom_api /api/v1/alerts '[.data.alerts[] | select(.labels.alertname=="TektonTooManyRunningTaskRuns") | .state] | first // empty')"
  [ "$state" = "firing" ] && break
  sleep 3
done
if [ "$state" != "firing" ]; then
  echo "FAIL: the alert TektonTooManyRunningTaskRuns is '${state:-inactive}' four minutes after three TaskRuns started running, expected 'firing'."
  exit 1
fi

recv=""
for _ in $(seq 1 40); do
  recv="$(kubectl -n monitoring exec deploy/client -- sh -c \
    'curl -fsS http://alertmanager.monitoring:9093/api/v2/alerts | jq -r "[.[] | select(.labels.alertname==\"TektonTooManyRunningTaskRuns\") | .receivers[].name] | first // empty"' 2>/dev/null)"
  [ -n "$recv" ] && break
  sleep 3
done
if [ "$recv" != "platform-oncall" ]; then
  echo "FAIL: Alertmanager holds the alert TektonTooManyRunningTaskRuns for the receiver '${recv:-none}', expected 'platform-oncall'."
  exit 1
fi

echo "PASS: the alert fires and Alertmanager routes it to platform-oncall."
exit 0
