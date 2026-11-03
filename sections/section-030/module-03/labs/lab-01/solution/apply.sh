#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays unsolved for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Write the routes and receivers.
kubectl apply -f "$SCRIPT_DIR/configmap-alertmanager-config.yaml"

# 2. Alertmanager reads its file at start (and on reload): restart it.
kubectl -n monitoring rollout restart deployment/alertmanager
kubectl -n monitoring rollout status deployment/alertmanager --timeout=300s
