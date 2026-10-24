#!/usr/bin/env bash
# PASS when chains-config asks for SLSA v1.0 provenance (slsa/v2alpha4) for
# TaskRuns, stores TaskRun attestations and image signatures in the OCI
# registry, keeps the transparency log off, and allows the plain-HTTP lab
# registry.
set -uo pipefail

read_key() {
  kubectl -n tekton-chains get configmap chains-config -o jsonpath="{.data.${1//./\\.}}" 2>/dev/null
}

check() {
  # check KEY EXPECTED
  local value
  value="$(read_key "$1")"
  if [ "$value" != "$2" ]; then
    echo "FAIL: chains-config has $1='${value}', expected '$2'."
    exit 1
  fi
}

check artifacts.taskrun.format slsa/v2alpha4
check artifacts.oci.storage oci
check transparency.enabled false
check storage.oci.repository.insecure true

storage="$(read_key artifacts.taskrun.storage)"
case ",${storage// /}," in
  *,oci,*) ;;
  *)
    echo "FAIL: artifacts.taskrun.storage is '${storage}'; it must include oci."
    exit 1 ;;
esac

echo "PASS: chains-config stores SLSA v1.0 TaskRun attestations and image signatures in the registry, without a transparency log."
exit 0
