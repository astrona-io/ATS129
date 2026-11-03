#!/usr/bin/env bash
# PASS when the ConfigMaps that Tekton Triggers reads carry the new values:
# feature-flags-triggers enable-api-fields=alpha and config-defaults-triggers
# default-service-account=triggers-sa. The Operator writes them after it
# installs Triggers, so the script waits up to six minutes for each value.
set -uo pipefail

wait_for_value() {
  # wait_for_value CONFIGMAP KEY EXPECTED
  local value=""
  for _ in $(seq 1 120); do
    value="$(kubectl -n tekton-pipelines get configmap "$1" -o jsonpath="{.data.${2//./\\.}}" 2>/dev/null)"
    [ "$value" = "$3" ] && return 0
    sleep 3
  done
  echo "FAIL: the ConfigMap $1 has $2='${value}', expected '$3'. The Operator writes it from spec.trigger of the TektonConfig."
  exit 1
}

wait_for_value feature-flags-triggers enable-api-fields alpha
wait_for_value config-defaults-triggers default-service-account triggers-sa

echo "PASS: feature-flags-triggers and config-defaults-triggers carry the values from the TektonConfig."
exit 0
