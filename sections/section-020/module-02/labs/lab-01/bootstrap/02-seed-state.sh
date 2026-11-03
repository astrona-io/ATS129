#!/usr/bin/env bash
# Creates the starting state for ats-129-lab-020-02.
#
# Creates the TektonConfig "config" with the profile lite and waits until the
# Tekton Operator has installed Tekton Pipelines and the TektonConfig is Ready.
#
# The TektonConfig sets only the profile, the target namespace and
# enable-api-fields: beta. Changing the Pipelines settings is the task.
set -euo pipefail

apply_with_retry() {
  # apply_with_retry: reads a manifest from standard input; the Operator
  # webhook can refuse the first objects while it starts.
  local manifest attempt
  manifest="$(mktemp)"
  cat > "$manifest"
  for attempt in $(seq 1 30); do
    if kubectl apply -f "$manifest"; then
      rm -f "$manifest"
      return 0
    fi
    echo "[lab] kubectl apply failed (attempt $attempt), retrying in 5s..."
    sleep 5
  done
  rm -f "$manifest"
  return 1
}

apply_with_retry <<'YAML'
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  name: config
spec:
  profile: lite
  targetNamespace: tekton-pipelines
  pipeline:
    enable-api-fields: beta
YAML

kubectl wait tektonconfig/config --for=condition=Ready --timeout=900s
kubectl -n tekton-pipelines rollout status deployment/tekton-pipelines-controller --timeout=300s
kubectl -n tekton-pipelines rollout status deployment/tekton-pipelines-webhook --timeout=300s

echo "[lab] Starting state ready."
kubectl get tektonconfig,tektonpipelines
