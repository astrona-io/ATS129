#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the capstone stays broken for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Put the right password next to the release key.
password="$(kubectl -n starfleet get secret release-key-escrow -o jsonpath='{.data.password}' | base64 -d)"
kubectl -n tekton-chains patch secret signing-secrets --type merge \
  -p "{\"stringData\":{\"cosign.password\":\"${password}\"}}"

# 2. Allow the plain-HTTP lab registry.
kubectl -n tekton-chains patch configmap chains-config --type merge \
  -p '{"data":{"storage.oci.repository.insecure":"true"}}'

# 3. Keep the "sha256:" prefix in IMAGE_DIGEST.
kubectl apply -f "$SCRIPT_DIR/task-release-image.yaml"

# 4. Restart Chains so it reads the fixed Secret at once.
kubectl -n tekton-chains rollout restart deployment/tekton-chains-controller
kubectl -n tekton-chains rollout status deployment/tekton-chains-controller --timeout=300s

# 5. Run the release again.
kubectl -n starfleet delete taskrun release-shuttle --ignore-not-found --wait=true
kubectl apply -f "$SCRIPT_DIR/taskrun-release-shuttle.yaml"
kubectl -n starfleet wait --for=condition=Succeeded taskrun/release-shuttle --timeout=300s
for _ in $(seq 1 60); do
  signed="$(kubectl -n starfleet get taskrun release-shuttle -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}')"
  [ "$signed" = "true" ] && break
  sleep 3
done
echo "release-shuttle: chains.tekton.dev/signed=${signed:-none}"
