#!/usr/bin/env bash
# PASS when starfleet and outpost each have the ConfigMap
# tekton-pruner-namespace-spec with both Pruner labels; starfleet sets
# ttlSecondsAfterFinished: 60, and outpost sets successfulHistoryLimit: 3 and
# failedHistoryLimit: 2 without a TTL.
set -uo pipefail

check_labels() {
  # check_labels NAMESPACE
  local part type
  part="$(kubectl -n "$1" get configmap tekton-pruner-namespace-spec -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}' 2>/dev/null)"
  type="$(kubectl -n "$1" get configmap tekton-pruner-namespace-spec -o jsonpath='{.metadata.labels.pruner\.tekton\.dev/config-type}' 2>/dev/null)"
  if [ "$part" != "tekton-pruner" ] || [ "$type" != "namespace" ]; then
    echo "FAIL: $1 needs the ConfigMap tekton-pruner-namespace-spec with the labels app.kubernetes.io/part-of=tekton-pruner and pruner.tekton.dev/config-type=namespace."
    exit 1
  fi
}

has_setting() {
  # has_setting CONFIG KEY VALUE: exit 0 when a line "KEY: VALUE" exists.
  [[ "$1" =~ (^|$'\n')[[:space:]]*$2:[[:space:]]*\"?$3\"?[[:space:]]*($'\n'|$) ]]
}

check_labels starfleet
check_labels outpost

starfleet="$(kubectl -n starfleet get configmap tekton-pruner-namespace-spec -o jsonpath='{.data.ns-config}')"
if ! has_setting "$starfleet" ttlSecondsAfterFinished 60; then
  echo "FAIL: the ns-config of starfleet must set ttlSecondsAfterFinished: 60."
  exit 1
fi

outpost="$(kubectl -n outpost get configmap tekton-pruner-namespace-spec -o jsonpath='{.data.ns-config}')"
if ! has_setting "$outpost" successfulHistoryLimit 3 || ! has_setting "$outpost" failedHistoryLimit 2; then
  echo "FAIL: the ns-config of outpost must set successfulHistoryLimit: 3 and failedHistoryLimit: 2."
  exit 1
fi
if [[ "$outpost" == *ttlSecondsAfterFinished* ]]; then
  echo "FAIL: outpost must keep its runs without a time limit; remove ttlSecondsAfterFinished from its ns-config."
  exit 1
fi

echo "PASS: starfleet has a 60-second TTL and outpost keeps 3 successful and 2 failed runs."
exit 0
