#!/usr/bin/env bash
# Creates the starting state for ats-129-capstone-030.
#
# 1. Applies the Task nightly-check in starfleet and runs it once.
# 2. Sets metrics-protocol: none in config-observability and restarts the
#    Tekton Pipelines controller, so it stops serving metrics.
#
# lab-start.yaml already gave Prometheus a Tekton scrape job on the wrong
# port and an alert with a wrong status value. Finding and fixing the three
# faults is the task.
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

echo "[lab] Switching the controller's metrics export off..."
kubectl -n tekton-pipelines patch configmap config-observability --type merge -p '{"data":{"metrics-protocol":"none"}}'
kubectl -n tekton-pipelines rollout restart deployment/tekton-pipelines-controller
kubectl -n tekton-pipelines rollout status deployment/tekton-pipelines-controller --timeout=300s

echo "[lab] Starting state ready."
kubectl -n monitoring get pods
