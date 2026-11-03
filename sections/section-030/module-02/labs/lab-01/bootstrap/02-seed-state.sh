#!/usr/bin/env bash
# Creates the starting state for ats-129-lab-030-02.
#
# 1. Applies the Tasks nightly-check and slow-check in starfleet.
# 2. Runs nightly-check once to pass and once to fail, so the controller
#    has counted one successful and one failed TaskRun.
#
# Prometheus already scrapes the Pipelines controller but has no rules.
# Writing the recording rule and the alert is the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"

apply_with_retry() {
  # apply_with_retry FILE: the webhook can refuse the first objects while it starts.
  local attempt
  for attempt in $(seq 1 30); do
    kubectl apply -f "$1" && return 0
    echo "[lab] kubectl apply -f $1 failed (attempt $attempt), retrying in 5s..."
    sleep 5
  done
  return 1
}

apply_with_retry "$MANIFESTS/task-nightly-check.yaml"
apply_with_retry "$MANIFESTS/task-slow-check.yaml"
for outcome in pass fail; do
  name="$(kubectl create -f - -o jsonpath='{.metadata.name}' <<YAML
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: nightly-${outcome}-
  namespace: starfleet
spec:
  taskRef:
    name: nightly-check
  params:
    - name: outcome
      value: ${outcome}
YAML
)"
  for _ in $(seq 1 100); do
    status="$(kubectl -n starfleet get taskrun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null || true)"
    [ "$status" = "True" ] || [ "$status" = "False" ] && break
    sleep 3
  done
  echo "[lab] TaskRun $name ended with Succeeded=$status."
done

echo "[lab] Starting state ready."
kubectl -n starfleet get taskruns
kubectl -n monitoring get pods
