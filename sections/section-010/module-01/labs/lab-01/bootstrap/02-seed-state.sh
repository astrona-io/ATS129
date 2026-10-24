#!/usr/bin/env bash
# Creates the starting state for ats-129-lab-010-01.
#
# 1. Applies the Task build-image (its results are named url and digest,
#    which Tekton Chains does not recognise).
# 2. Applies the TaskRun build-bridge and waits until it has ended.
# 3. Waits until Tekton Chains has handled the run. Chains has no signing
#    key and the default chains-config, so nothing is signed or pushed.
#
# Generating the key, configuring Chains and fixing the Task is the task.
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

wait_for_taskrun_end() {
  # wait_for_taskrun_end NAME: waits until the Succeeded condition is True or False.
  local status=""
  for _ in $(seq 1 100); do
    status="$(kubectl -n starfleet get taskrun "$1" \
      -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null || true)"
    if [ "$status" = "True" ] || [ "$status" = "False" ]; then
      echo "[lab] TaskRun $1 ended with Succeeded=$status."
      return 0
    fi
    sleep 3
  done
  echo "ERROR: TaskRun $1 did not end in time." >&2
  return 1
}

wait_for_chains() {
  # wait_for_chains NAME: waits until Tekton Chains has written its
  # chains.tekton.dev/signed annotation (any value).
  local signed=""
  for _ in $(seq 1 40); do
    signed="$(kubectl -n starfleet get taskrun "$1" \
      -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}' 2>/dev/null || true)"
    if [ -n "$signed" ]; then
      echo "[lab] Tekton Chains handled $1 (chains.tekton.dev/signed=$signed)."
      return 0
    fi
    sleep 3
  done
  echo "[lab] Tekton Chains has not annotated $1 yet; continuing."
}

apply_with_retry "$MANIFESTS/task-build-image.yaml"
apply_with_retry "$MANIFESTS/taskrun-build-bridge.yaml"
wait_for_taskrun_end build-bridge
wait_for_chains build-bridge

echo "[lab] Starting state ready."
kubectl -n starfleet get tasks,taskruns
