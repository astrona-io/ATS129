#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays unsolved for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. A cosign key pair in the Secret signing-secrets. cosign runs in the
#    workstation pod, whose ServiceAccount may write that Secret. Skip it when
#    a key is already there (cosign marks the Secret immutable).
have_key="$(kubectl -n tekton-chains get secret signing-secrets -o jsonpath='{.data.cosign\.key}' 2>/dev/null || true)"
if [ -z "$have_key" ]; then
  kubectl -n workstation exec deploy/workstation -- \
    env COSIGN_PASSWORD=lab-only-password cosign generate-key-pair k8s://tekton-chains/signing-secrets
fi

# 2. Configure Chains.
kubectl apply -f "$SCRIPT_DIR/configmap-chains-config.yaml"

# 3. Fix the type-hinting results of the Task.
kubectl apply -f "$SCRIPT_DIR/task-build-image.yaml"

# 4. Restart the Chains controller so it mounts the new Secret at once.
kubectl -n tekton-chains rollout restart deployment/tekton-chains-controller
kubectl -n tekton-chains rollout status deployment/tekton-chains-controller --timeout=300s

# 5. Chains never signs a TaskRun twice: create build-bridge again.
kubectl -n starfleet delete taskrun build-bridge --ignore-not-found --wait=true
kubectl apply -f "$SCRIPT_DIR/taskrun-build-bridge.yaml"
kubectl -n starfleet wait --for=condition=Succeeded taskrun/build-bridge --timeout=300s
for _ in $(seq 1 60); do
  signed="$(kubectl -n starfleet get taskrun build-bridge -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}')"
  [ "$signed" = "true" ] && break
  sleep 3
done
echo "build-bridge: chains.tekton.dev/signed=${signed:-none}"
