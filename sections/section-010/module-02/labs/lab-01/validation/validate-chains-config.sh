#!/usr/bin/env bash
# PASS when chains-config asks for SLSA v1.0 provenance (slsa/v2alpha4) for
# TaskRuns, stores TaskRun provenance in both the TaskRun annotations (tekton)
# and the OCI registry (oci), and keeps the settings of the starting state.
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
for backend in tekton oci; do
  case ",${storage// /}," in
    *,"$backend",*) ;;
    *)
      echo "FAIL: artifacts.taskrun.storage is '${storage}'; it must include ${backend}."
      exit 1 ;;
  esac
done

echo "PASS: chains-config sets slsa/v2alpha4 and stores TaskRun provenance in tekton and oci."
exit 0
