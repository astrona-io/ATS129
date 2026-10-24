#!/usr/bin/env bash
# Runs before the reference solution is applied.
#
# `astrona test` bootstraps and applies in one go. Wait until every Tekton
# Deployment and Prometheus are Available, so the reference solution
# never races a controller that is still starting.
set -euo pipefail

for namespace in tekton-pipelines tekton-pipelines-resolvers monitoring; do
  deployments="$(kubectl -n "$namespace" get deployment -o name 2>/dev/null || true)"
  for deployment in $deployments; do
    replicas="$(kubectl -n "$namespace" get "$deployment" -o jsonpath='{.spec.replicas}')"
    [ "$replicas" = "0" ] && continue
    kubectl -n "$namespace" rollout status "$deployment" --timeout=300s
  done
done
kubectl get namespace starfleet >/dev/null
echo "[test] Tekton and Prometheus are ready."
