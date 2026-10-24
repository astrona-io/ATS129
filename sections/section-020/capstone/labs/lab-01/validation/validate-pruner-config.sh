#!/usr/bin/env bash
# PASS when the global Pruner configuration allows namespace settings, the
# starfleet settings live in a correctly named and labelled
# tekton-pruner-namespace-spec with ttlSecondsAfterFinished: 60, and the
# wrongly named ConfigMap is gone.
set -uo pipefail

global="$(kubectl -n tekton-pipelines get configmap tekton-pruner-default-spec -o jsonpath='{.data.global-config}' 2>/dev/null)"
if ! [[ "$global" =~ (^|$'\n')[[:space:]]*enforcedConfigLevel:[[:space:]]*\"?namespace\"?[[:space:]]*($'\n'|$) ]]; then
  echo "FAIL: the global-config in tekton-pruner-default-spec must set enforcedConfigLevel: namespace."
  exit 1
fi
if [[ "$global" == *ttlSecondsAfterFinished* ]]; then
  echo "FAIL: the global-config must not set a TTL; only starfleet deletes its runs after 60 seconds."
  exit 1
fi

part="$(kubectl -n starfleet get configmap tekton-pruner-namespace-spec -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}' 2>/dev/null)"
type="$(kubectl -n starfleet get configmap tekton-pruner-namespace-spec -o jsonpath='{.metadata.labels.pruner\.tekton\.dev/config-type}' 2>/dev/null)"
if [ "$part" != "tekton-pruner" ] || [ "$type" != "namespace" ]; then
  echo "FAIL: starfleet needs the ConfigMap tekton-pruner-namespace-spec with the labels app.kubernetes.io/part-of=tekton-pruner and pruner.tekton.dev/config-type=namespace."
  exit 1
fi
config="$(kubectl -n starfleet get configmap tekton-pruner-namespace-spec -o jsonpath='{.data.ns-config}')"
if ! [[ "$config" =~ (^|$'\n')[[:space:]]*ttlSecondsAfterFinished:[[:space:]]*\"?60\"?[[:space:]]*($'\n'|$) ]]; then
  echo "FAIL: the ns-config of tekton-pruner-namespace-spec in starfleet must set ttlSecondsAfterFinished: 60."
  exit 1
fi
if kubectl -n starfleet get configmap tekton-pruner-namespace-config >/dev/null 2>&1; then
  echo "FAIL: the wrongly named ConfigMap tekton-pruner-namespace-config is still in starfleet; remove it."
  exit 1
fi

echo "PASS: namespace settings are allowed and starfleet has a correct tekton-pruner-namespace-spec."
exit 0
