#!/usr/bin/env bash
# PASS when the TektonConfig is Ready, the TektonTrigger resource exists and
# is Ready, and the Triggers controller and webhook Deployments are Available.
# The Operator installs Triggers after the profile change, so the script waits.
set -uo pipefail

if ! kubectl wait tektonconfig/config --for=condition=Ready --timeout=600s >/dev/null 2>&1; then
  reason="$(kubectl get tektonconfig config -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)"
  echo "FAIL: the TektonConfig is not Ready within ten minutes (${reason:-no message})."
  exit 1
fi
if ! kubectl get tektontrigger.operator.tekton.dev trigger >/dev/null 2>&1; then
  echo "FAIL: the resource TektonTrigger 'trigger' does not exist. Does the profile include Triggers?"
  exit 1
fi
if ! kubectl wait tektontrigger.operator.tekton.dev/trigger --for=condition=Ready --timeout=300s >/dev/null 2>&1; then
  echo "FAIL: the TektonTrigger is not Ready."
  exit 1
fi
for deployment in tekton-triggers-controller tekton-triggers-webhook; do
  if ! kubectl -n tekton-pipelines rollout status "deployment/$deployment" --timeout=180s >/dev/null 2>&1; then
    echo "FAIL: the Deployment $deployment is not available."
    exit 1
  fi
done

echo "PASS: the TektonConfig is Ready and Tekton Triggers runs."
exit 0
