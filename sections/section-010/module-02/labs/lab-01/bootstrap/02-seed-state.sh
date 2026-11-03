#!/usr/bin/env bash
# Creates the starting state for ats-129-lab-010-02.
#
# 1. Generates the cosign key pair in the Secret signing-secrets (cosign runs in
#    the workstation pod).
# 2. Applies a chains-config that signs images into the registry with no
#    transparency log, and leaves the TaskRun provenance format and storage at
#    their defaults (format in-toto, storage tekton).
# 3. Applies the Task build-image (with the type-hinting results) and the
#    TaskRun build-bridge, and waits until Chains has signed it.
#
# Choosing the SLSA v1.0 format and the storage backends is the task.
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

wait_for_taskrun_end() {
  local status=""
  for _ in $(seq 1 100); do
    status="$(kubectl -n starfleet get taskrun "$1" \
      -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null || true)"
    if [ "$status" = "True" ] || [ "$status" = "False" ]; then
      echo "[lab] TaskRun $1 ended with Succeeded=$status."
      return 0
    fi
    sleep 3
  done
  echo "ERROR: TaskRun $1 did not end in time." >&2
  return 1
}

wait_for_chains() {
  local signed=""
  for _ in $(seq 1 60); do
    signed="$(kubectl -n starfleet get taskrun "$1" \
      -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}' 2>/dev/null || true)"
    if [ -n "$signed" ]; then
      echo "[lab] Tekton Chains handled $1 (chains.tekton.dev/signed=$signed)."
      return 0
    fi
    sleep 3
  done
  echo "[lab] Tekton Chains has not annotated $1 yet; continuing."
}

have_key="$(kubectl -n tekton-chains get secret signing-secrets -o jsonpath='{.data.cosign\.key}' 2>/dev/null || true)"
if [ -z "$have_key" ]; then
  kubectl -n workstation exec deploy/workstation -- \
    env COSIGN_PASSWORD=lab-only-password cosign generate-key-pair k8s://tekton-chains/signing-secrets
fi

apply_with_retry "$MANIFESTS/configmap-chains-config.yaml"
kubectl -n tekton-chains rollout restart deployment/tekton-chains-controller
kubectl -n tekton-chains rollout status deployment/tekton-chains-controller --timeout=300s

apply_with_retry "$MANIFESTS/task-build-image.yaml"
apply_with_retry "$MANIFESTS/taskrun-build-bridge.yaml"
wait_for_taskrun_end build-bridge
wait_for_chains build-bridge

echo "[lab] Starting state ready."
kubectl -n starfleet get tasks,taskruns
