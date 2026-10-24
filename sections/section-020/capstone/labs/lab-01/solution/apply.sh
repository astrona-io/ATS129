#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the capstone stays broken for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apply_with_retry() {
  # apply_with_retry FILE: retried while the Pruner webhook starts.
  local attempt
  for attempt in $(seq 1 30); do
    kubectl apply -f "$1" && return 0
    sleep 5
  done
  return 1
}

# 1. Bring the Pruner webhook back.
kubectl -n tekton-pipelines scale deployment tekton-pruner-webhook --replicas=1
kubectl -n tekton-pipelines rollout status deployment/tekton-pruner-webhook --timeout=300s

# 2. Allow namespace-level settings.
apply_with_retry "$SCRIPT_DIR/configmap-tekton-pruner-default-spec.yaml"

# 3. Replace the wrongly named ConfigMap with tekton-pruner-namespace-spec.
apply_with_retry "$SCRIPT_DIR/configmap-pruner-starfleet.yaml"
kubectl -n starfleet delete configmap tekton-pruner-namespace-config --ignore-not-found
