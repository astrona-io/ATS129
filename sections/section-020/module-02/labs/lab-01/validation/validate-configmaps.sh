#!/usr/bin/env bash
# PASS when the ConfigMaps that Tekton Pipelines reads carry the new values:
# feature-flags enable-api-fields=stable, config-defaults
# default-timeout-minutes=30 and config-logging loglevel.controller=debug.
# The Operator writes them after it reconciles the TektonConfig, so the
# script waits up to three minutes for each value.
set -uo pipefail

wait_for_value() {
  # wait_for_value CONFIGMAP KEY EXPECTED
  local value=""
  for _ in $(seq 1 60); do
    value="$(kubectl -n tekton-pipelines get configmap "$1" -o jsonpath="{.data.${2//./\\.}}" 2>/dev/null)"
    [ "$value" = "$3" ] && return 0
    sleep 3
  done
  echo "FAIL: the ConfigMap $1 has $2='${value}', expected '$3'. The Operator writes it from the TektonConfig."
  exit 1
}

wait_for_value feature-flags enable-api-fields stable
wait_for_value config-defaults default-timeout-minutes 30
wait_for_value config-logging loglevel.controller debug

echo "PASS: feature-flags, config-defaults and config-logging carry the values from the TektonConfig."
exit 0
