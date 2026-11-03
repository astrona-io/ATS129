#!/usr/bin/env bash
# PASS when the TektonConfig "config" has the profile basic, keeps its target
# namespace and the Pipelines setting enable-api-fields=beta, and sets
# spec.trigger.enable-api-fields=alpha and
# spec.trigger.default-service-account=triggers-sa.
set -uo pipefail

check() {
  # check DESCRIPTION JSONPATH EXPECTED
  local value
  value="$(kubectl get tektonconfig config -o jsonpath="$2" 2>/dev/null)"
  if [ "$value" != "$3" ]; then
    echo "FAIL: $1 is '${value}' in the TektonConfig, expected '$3'."
    exit 1
  fi
}

check "spec.profile" '{.spec.profile}' basic
check "spec.targetNamespace" '{.spec.targetNamespace}' tekton-pipelines
check "spec.pipeline.enable-api-fields" '{.spec.pipeline.enable-api-fields}' beta
check "spec.trigger.enable-api-fields" '{.spec.trigger.enable-api-fields}' alpha
check "spec.trigger.default-service-account" '{.spec.trigger.default-service-account}' triggers-sa

echo "PASS: the TektonConfig uses the profile basic and sets the two Triggers properties."
exit 0
