#!/usr/bin/env bash
# PASS when the TektonConfig is Ready after the change and the Pipelines
# controller Deployment is Available. The Operator restarts or updates
# components after a change, so the script waits for both.
set -uo pipefail

if ! kubectl wait tektonconfig/config --for=condition=Ready --timeout=300s >/dev/null 2>&1; then
  reason="$(kubectl get tektonconfig config -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)"
  echo "FAIL: the TektonConfig is not Ready within five minutes (${reason:-no message})."
  exit 1
fi
if ! kubectl -n tekton-pipelines rollout status deployment/tekton-pipelines-controller --timeout=180s >/dev/null 2>&1; then
  echo "FAIL: the Deployment tekton-pipelines-controller is not available."
  exit 1
fi

echo "PASS: the TektonConfig is Ready and the Pipelines controller runs."
exit 0
