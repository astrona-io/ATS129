#!/usr/bin/env bash
# PASS when the Pruner keeps at most 3 successful and 2 failed TaskRuns in
# outpost and gives them no TTL: the grader runs nightly-check four times
# successfully and three times with a failure, then counts what is left.
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

count_runs() {
  # count_runs STATUS: number of runs in outpost whose Succeeded is STATUS.
  kubectl -n "$NS" get taskruns -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Succeeded")].status}{"\n"}{end}' 2>/dev/null \
    | grep -c "^$1\$"
}

cleanup() {
  kubectl -n "$NS" delete taskruns -l astrona.io/grader=true --wait=false >/dev/null 2>&1 || true
}

first_pass=""
last_pass=""
for outcome in pass pass pass pass fail fail fail; do
  name="$(start_run "$NS" "$outcome")"
  if [ -z "$name" ]; then
    cleanup
    echo "FAIL: the grader could not start a TaskRun of nightly-check in $NS."
    exit 1
  fi
  wait_for_end "$NS" "$name" >/dev/null
  if [ "$outcome" = "pass" ]; then
    [ -z "$first_pass" ] && first_pass="$name"
    last_pass="$name"
  fi
done

passed=99
failed=99
for _ in $(seq 1 30); do
  passed="$(count_runs True)"
  failed="$(count_runs False)"
  [ "$passed" -le 3 ] && [ "$failed" -le 2 ] && break
  sleep 3
done
ttl="$(ttl_annotation "$NS" "$last_pass")"
newest_kept="no"
run_exists "$NS" "$last_pass" && newest_kept="yes"
oldest_kept="no"
run_exists "$NS" "$first_pass" && oldest_kept="yes"
cleanup

if [ "$passed" -gt 3 ] || [ "$failed" -gt 2 ]; then
  echo "FAIL: $NS still has $passed successful and $failed failed runs; expected at most 3 and 2."
  exit 1
fi
if [ "$newest_kept" != "yes" ] || [ "$oldest_kept" != "no" ]; then
  echo "FAIL: the Pruner must keep the newest runs and delete the oldest (newest kept: $newest_kept, oldest of four kept: $oldest_kept)."
  exit 1
fi
if [ -n "$ttl" ] && [ "$ttl" != "-1" ]; then
  echo "FAIL: runs in $NS got a TTL of '$ttl' seconds; outpost must keep its runs without a time limit."
  exit 1
fi

echo "PASS: $NS keeps the 3 newest successful and the 2 newest failed runs, with no TTL."
exit 0
