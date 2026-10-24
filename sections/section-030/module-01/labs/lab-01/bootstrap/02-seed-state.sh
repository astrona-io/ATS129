#!/usr/bin/env bash
# Creates the starting state for ats-129-lab-030-01.
#
# 1. Applies the Task nightly-check in starfleet.
# 2. Runs it once successfully, so the controller has counted a TaskRun.
#
# Prometheus scrapes only itself and has no alerting rules. Adding the
# Tekton scrape job and the alert is the task.
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
name="$(kubectl create -f - -o jsonpath='{.metadata.name}' <<'YAML'
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: nightly-
  namespace: starfleet
spec:
  taskRef:
    name: nightly-check
YAML
)"
kubectl -n starfleet wait --for=condition=Succeeded "taskrun/$name" --timeout=300s

echo "[lab] Starting state ready."
kubectl -n starfleet get taskruns
kubectl -n monitoring get pods
