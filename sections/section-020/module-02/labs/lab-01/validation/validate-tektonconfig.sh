#!/usr/bin/env bash
# PASS when the TektonConfig "config" keeps the profile lite and its target
# namespace, and sets enable-api-fields to stable, default-timeout-minutes to
# 30 and loglevel.controller to debug in options.configMaps.config-logging.
set -uo pipefail

read_config() {
  kubectl get tektonconfig config -o jsonpath="$1" 2>/dev/null
}

check() {
  # check DESCRIPTION JSONPATH EXPECTED
  local value
  value="$(read_config "$2")"
  if [ "$value" != "$3" ]; then
    echo "FAIL: $1 is '${value}' in the TektonConfig, expected '$3'."
    exit 1
  fi
}

check "spec.profile" '{.spec.profile}' lite
check "spec.targetNamespace" '{.spec.targetNamespace}' tekton-pipelines
check "spec.pipeline.enable-api-fields" '{.spec.pipeline.enable-api-fields}' stable
check "spec.pipeline.default-timeout-minutes" '{.spec.pipeline.default-timeout-minutes}' 30
check "spec.pipeline.options.configMaps.config-logging.data.loglevel.controller" '{.spec.pipeline.options.configMaps.config-logging.data.loglevel\.controller}' debug

echo "PASS: the TektonConfig sets enable-api-fields, default-timeout-minutes and the controller log level."
exit 0
