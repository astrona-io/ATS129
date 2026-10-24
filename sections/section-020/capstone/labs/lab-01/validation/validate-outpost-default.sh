#!/usr/bin/env bash
# PASS when outpost keeps the global default: a grader run in outpost gets
# no TTL annotation and still exists 30 seconds after it ended. A global TTL
# would fail here.
set -uo pipefail

NS="outpost"
# start_run NAMESPACE OUTCOME [PREFIX]: creates a TaskRun of nightly-check
# with generateName and prints its name.
start_run() {
  local manifest name
  manifest="$(mktemp)"
  cat > "$manifest" <<YAML
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: ${3:-nightly-grader}-
  namespace: $1
  labels:
    astrona.io/grader: "true"
spec:
  taskRef:
    name: nightly-check
  params:
    - name: outcome
      value: $2
YAML
  name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
  rm -f "$manifest"
  printf '%s' "$name"
}

# wait_for_end NAMESPACE NAME: waits up to 3 minutes until the run ended and
# prints its Succeeded status (True or False).
wait_for_end() {
  local status=""
  for _ in $(seq 1 60); do
    status="$(kubectl -n "$1" get taskrun "$2" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
    [ "$status" = "True" ] || [ "$status" = "False" ] && break
    sleep 3
  done
  printf '%s' "$status"
}

# ttl_annotation NAMESPACE NAME: prints the TTL the Pruner wrote on a run.
ttl_annotation() {
  kubectl -n "$1" get taskrun "$2" -o jsonpath='{.metadata.annotations.pruner\.tekton\.dev/ttlSecondsAfterFinished}' 2>/dev/null
}

# run_exists NAMESPACE NAME: exit 0 while the run still exists.
run_exists() {
  kubectl -n "$1" get taskrun "$2" >/dev/null 2>&1
}

name="$(start_run "$NS" pass)"
if [ -z "$name" ]; then
  echo "FAIL: the grader could not start a TaskRun of nightly-check in $NS."
  exit 1
fi
status="$(wait_for_end "$NS" "$name")"
sleep 30
ttl="$(ttl_annotation "$NS" "$name")"
exists="no"
run_exists "$NS" "$name" && exists="yes"
kubectl -n "$NS" delete taskrun "$name" --wait=false >/dev/null 2>&1 || true

if [ "$status" != "True" ]; then
  echo "FAIL: the grader TaskRun in $NS did not succeed (Succeeded=${status:-none})."
  exit 1
fi
if [ -n "$ttl" ] && [ "$ttl" != "-1" ]; then
  echo "FAIL: a run in $NS got a TTL of '$ttl' seconds; only starfleet may delete its runs after a time."
  exit 1
fi
if [ "$exists" != "yes" ]; then
  echo "FAIL: a successful run in $NS was deleted 30 seconds after it ended; outpost must keep the global default."
  exit 1
fi

echo "PASS: $NS keeps its runs under the global default, with no TTL."
exit 0
