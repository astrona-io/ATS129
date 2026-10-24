#!/usr/bin/env bash
# PASS when the alert TektonTaskRunFailed fires after a TaskRun fails: the
# grader runs nightly-check with outcome=fail and waits up to three minutes
# for the alert to be in the state firing.
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

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: nightly-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  taskRef:
    name: nightly-check
  params:
    - name: outcome
      value: fail
YAML
name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
if [ -z "$name" ]; then
  echo "FAIL: the grader could not create a TaskRun of nightly-check."
  exit 1
fi
status=""
for _ in $(seq 1 60); do
  status="$(kubectl -n "$NS" get taskrun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
if [ "$status" != "False" ]; then
  kubectl -n "$NS" delete taskrun "$name" --wait=false >/dev/null 2>&1 || true
  echo "FAIL: the grader TaskRun with outcome=fail did not fail (Succeeded=${status:-none})."
  exit 1
fi

state=""
for _ in $(seq 1 60); do
  state="$(prom_api /api/v1/alerts '[.data.alerts[] | select(.labels.alertname=="TektonTaskRunFailed") | .state] | first // empty')"
  [ "$state" = "firing" ] && break
  sleep 3
done
kubectl -n "$NS" delete taskrun "$name" --wait=false >/dev/null 2>&1 || true
if [ "$state" != "firing" ]; then
  echo "FAIL: the alert TektonTaskRunFailed is '${state:-inactive}' three minutes after a TaskRun failed, expected 'firing'."
  exit 1
fi

echo "PASS: the alert TektonTaskRunFailed fires after a TaskRun fails."
exit 0
