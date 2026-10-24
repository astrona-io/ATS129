#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the capstone stays broken for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Serve the controller metrics again (Prometheus format on port 9090).
kubectl -n tekton-pipelines patch configmap config-observability --type merge -p '{"data":{"metrics-protocol":"prometheus"}}'
kubectl -n tekton-pipelines rollout restart deployment/tekton-pipelines-controller
kubectl -n tekton-pipelines rollout status deployment/tekton-pipelines-controller --timeout=300s

# 2. Scrape the metrics port and compare with the real status value.
kubectl apply -f "$SCRIPT_DIR/configmap-prometheus-config.yaml"
kubectl -n monitoring rollout restart deployment/prometheus
kubectl -n monitoring rollout status deployment/prometheus --timeout=300s
