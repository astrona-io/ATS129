#!/usr/bin/env bash
# PASS when the Pruner deletes a finished TaskRun in starfleet about 60
# seconds after it ends: the grader starts a run, waits for the Pruner to
# write the annotation pruner.tekton.dev/ttlSecondsAfterFinished=60, and then
# waits for the run to disappear.
set -uo pipefail

NS="starfleet"
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
if [ "$status" != "True" ]; then
  kubectl -n "$NS" delete taskrun "$name" --wait=false >/dev/null 2>&1 || true
  echo "FAIL: the grader TaskRun $name did not succeed (Succeeded=${status:-none})."
  exit 1
fi

ttl=""
for _ in $(seq 1 20); do
  ttl="$(ttl_annotation "$NS" "$name")"
  [ -n "$ttl" ] && break
  run_exists "$NS" "$name" || break
  sleep 3
done
if [ -n "$ttl" ] && [ "$ttl" != "60" ]; then
  kubectl -n "$NS" delete taskrun "$name" --wait=false >/dev/null 2>&1 || true
  echo "FAIL: the Pruner gave the run $name a TTL of '$ttl' seconds, expected 60."
  exit 1
fi

for _ in $(seq 1 60); do
  run_exists "$NS" "$name" || break
  sleep 3
done
if run_exists "$NS" "$name"; then
  kubectl -n "$NS" delete taskrun "$name" --wait=false >/dev/null 2>&1 || true
  echo "FAIL: the finished run $name in $NS still exists 3 minutes after it ended; the Pruner did not apply a 60-second TTL."
  exit 1
fi

echo "PASS: the Pruner deleted a finished run in $NS within the 60-second TTL."
exit 0
