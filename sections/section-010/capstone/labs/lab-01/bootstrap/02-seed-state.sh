#!/usr/bin/env bash
# Creates the starting state for ats-129-capstone-010.
#
# 1. Creates the release key pair in the workstation (password
#    release-2026-lab-only) and stores it in signing-secrets with a WRONG
#    cosign.password. The right password goes to the Secret
#    release-key-escrow in starfleet; the public key to the ConfigMap
#    release-key in starfleet and, for the graders, to the ConfigMap
#    lab-baseline-release-pub in workstation.
# 2. Configures chains-config for SLSA v1.0 attestations in the registry,
#    WITHOUT storage.oci.repository.insecure.
# 3. Applies the Task release-image (it writes IMAGE_DIGEST without the
#    "sha256:" prefix) and the TaskRun release-shuttle, and waits until
#    Chains has handled the run.
#
# Finding and fixing the three faults is the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"
RIGHT_PASSWORD="release-2026-lab-only"
WRONG_PASSWORD="release-2025-lab-only"

ws() { kubectl -n workstation exec deploy/workstation -- "$@"; }

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

KEY_DIR="$(mktemp -d)"
trap 'rm -rf "$KEY_DIR"' EXIT

echo "[lab] Creating the release key pair..."
ws sh -c "mkdir -p /work/keys && cd /work/keys && rm -f release.key release.pub && COSIGN_PASSWORD=$RIGHT_PASSWORD cosign generate-key-pair --output-key-prefix release >/dev/null"
ws cat /work/keys/release.key > "$KEY_DIR/release.key"
ws cat /work/keys/release.pub > "$KEY_DIR/release.pub"
[ -s "$KEY_DIR/release.key" ] && [ -s "$KEY_DIR/release.pub" ] || { echo "ERROR: the release key pair is empty." >&2; exit 1; }

kubectl -n tekton-chains delete secret signing-secrets --ignore-not-found
kubectl -n tekton-chains create secret generic signing-secrets \
  --from-file=cosign.key="$KEY_DIR/release.key" \
  --from-file=cosign.pub="$KEY_DIR/release.pub" \
  --from-literal=cosign.password="$WRONG_PASSWORD"
kubectl -n starfleet create secret generic release-key-escrow \
  --from-literal=password="$RIGHT_PASSWORD" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n starfleet create configmap release-key \
  --from-file=cosign.pub="$KEY_DIR/release.pub" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n workstation create configmap lab-baseline-release-pub \
  --from-file=cosign.pub="$KEY_DIR/release.pub" --dry-run=client -o yaml | kubectl apply -f -

echo "[lab] Configuring Tekton Chains..."
kubectl -n tekton-chains patch configmap chains-config --type merge -p '{"data":{
  "artifacts.taskrun.format":"slsa/v2alpha4",
  "artifacts.taskrun.storage":"oci",
  "artifacts.oci.storage":"oci",
  "transparency.enabled":"false"}}'
# Restart so the controller mounts the new Secret before the first run.
kubectl -n tekton-chains rollout restart deployment/tekton-chains-controller
kubectl -n tekton-chains rollout status deployment/tekton-chains-controller --timeout=300s

apply_with_retry "$MANIFESTS/task-release-image.yaml"
apply_with_retry "$MANIFESTS/taskrun-release-shuttle.yaml"

status=""
for _ in $(seq 1 100); do
  status="$(kubectl -n starfleet get taskrun release-shuttle -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null || true)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
echo "[lab] TaskRun release-shuttle ended with Succeeded=${status:-unknown}."
for _ in $(seq 1 40); do
  signed="$(kubectl -n starfleet get taskrun release-shuttle -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}' 2>/dev/null || true)"
  [ -n "$signed" ] && break
  sleep 3
done
echo "[lab] Tekton Chains annotation on release-shuttle: chains.tekton.dev/signed=${signed:-none}."

echo "[lab] Starting state ready."
kubectl -n starfleet get tasks,taskruns
