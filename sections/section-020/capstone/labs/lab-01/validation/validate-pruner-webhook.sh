#!/usr/bin/env bash
# PASS when the Pruner webhook has a ready replica and admits a change to
# the global Pruner ConfigMap (a server-side dry run).
set -uo pipefail

ready="$(kubectl -n tekton-pipelines get deployment tekton-pruner-webhook -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
if [ -z "$ready" ] || [ "$ready" -lt 1 ]; then
  echo "FAIL: the Deployment tekton-pruner-webhook in tekton-pipelines has no ready replica."
  exit 1
fi

admitted="no"
for _ in $(seq 1 10); do
  if kubectl -n tekton-pipelines label configmap tekton-pruner-default-spec astrona.io/grader=probe \
    --overwrite --dry-run=server >/dev/null 2>&1; then
    admitted="yes"
    break
  fi
  sleep 3
done
if [ "$admitted" != "yes" ]; then
  echo "FAIL: the API server refuses changes to tekton-pruner-default-spec; the Pruner webhook does not answer."
  exit 1
fi

echo "PASS: the Pruner webhook runs and validates the Pruner ConfigMaps."
exit 0
