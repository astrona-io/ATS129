#!/usr/bin/env bash
# PASS when the global Pruner ConfigMap tekton-pruner-default-spec allows
# namespace-level settings (enforcedConfigLevel: namespace) and keeps the
# cluster-wide historyLimit of 100.
set -uo pipefail

config="$(kubectl -n tekton-pipelines get configmap tekton-pruner-default-spec -o jsonpath='{.data.global-config}' 2>/dev/null)"
if [ -z "$config" ]; then
  echo "FAIL: the ConfigMap tekton-pruner-default-spec in tekton-pipelines has no global-config."
  exit 1
fi
if ! [[ "$config" =~ (^|$'\n')[[:space:]]*enforcedConfigLevel:[[:space:]]*\"?namespace\"?[[:space:]]*($'\n'|$) ]]; then
  echo "FAIL: global-config must set enforcedConfigLevel: namespace, or the Pruner ignores the namespace ConfigMaps."
  exit 1
fi
if ! [[ "$config" =~ (^|$'\n')historyLimit:[[:space:]]*100[[:space:]]*($'\n'|$) ]]; then
  echo "FAIL: global-config must keep the cluster-wide historyLimit: 100."
  exit 1
fi
for label in app.kubernetes.io/part-of=tekton-pruner pruner.tekton.dev/config-type=global; do
  key="${label%%=*}"; want="${label#*=}"
  have="$(kubectl -n tekton-pipelines get configmap tekton-pruner-default-spec -o jsonpath="{.metadata.labels.${key//./\\.}}")"
  if [ "$have" != "$want" ]; then
    echo "FAIL: tekton-pruner-default-spec must keep the label $key=$want."
    exit 1
  fi
done

echo "PASS: the global Pruner configuration allows namespace settings and keeps historyLimit: 100."
exit 0
