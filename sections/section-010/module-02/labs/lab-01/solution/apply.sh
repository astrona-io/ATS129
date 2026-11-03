#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays unsolved for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Choose the format and the storage backends.
kubectl apply -f "$SCRIPT_DIR/configmap-chains-config.yaml"

# 2. Chains reads chains-config on every run; restart to be safe.
kubectl -n tekton-chains rollout restart deployment/tekton-chains-controller
kubectl -n tekton-chains rollout status deployment/tekton-chains-controller --timeout=300s

# 3. Chains never signs a TaskRun twice: create build-bridge again.
kubectl -n starfleet delete taskrun build-bridge --ignore-not-found --wait=true
kubectl apply -f "$SCRIPT_DIR/taskrun-build-bridge.yaml"
kubectl -n starfleet wait --for=condition=Succeeded taskrun/build-bridge --timeout=300s
for _ in $(seq 1 60); do
  signed="$(kubectl -n starfleet get taskrun build-bridge -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}')"
  [ "$signed" = "true" ] && break
  sleep 3
done
echo "build-bridge: chains.tekton.dev/signed=${signed:-none}"
