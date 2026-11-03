#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays unsolved for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change the settings in the TektonConfig, the only place the Operator reads.
kubectl apply -f "$SCRIPT_DIR/tektonconfig-config.yaml"
kubectl wait tektonconfig/config --for=condition=Ready --timeout=600s
