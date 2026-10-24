#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays unsolved for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apply_with_retry() {
  # apply_with_retry FILE: the Pruner webhook validates these ConfigMaps.
  local attempt
  for attempt in $(seq 1 30); do
    kubectl apply -f "$1" && return 0
    sleep 5
  done
  return 1
}

# 1. Allow namespace-level settings; keep the global history limit.
apply_with_retry "$SCRIPT_DIR/configmap-tekton-pruner-default-spec.yaml"
# 2. Time-based pruning for starfleet, history-based pruning for outpost.
apply_with_retry "$SCRIPT_DIR/configmap-pruner-starfleet.yaml"
apply_with_retry "$SCRIPT_DIR/configmap-pruner-outpost.yaml"
# 3. Restart the Pruner controller so it reads every existing run again
#    (it applies the new TTL to old runs only when it sees them again).
kubectl -n tekton-pipelines rollout restart deployment/tekton-pruner-controller
kubectl -n tekton-pipelines rollout status deployment/tekton-pruner-controller --timeout=300s
