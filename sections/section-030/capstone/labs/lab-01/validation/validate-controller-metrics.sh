#!/usr/bin/env bash
# PASS when config-observability exports metrics in the Prometheus format
# and the Tekton Pipelines controller serves Tekton metrics on its
# http-metrics port (read through the API server's Service proxy).
set -uo pipefail

protocol="$(kubectl -n tekton-pipelines get configmap config-observability -o jsonpath='{.data.metrics-protocol}' 2>/dev/null)"
if [ "$protocol" != "prometheus" ]; then
  echo "FAIL: config-observability in tekton-pipelines has metrics-protocol='${protocol}', expected 'prometheus'."
  exit 1
fi

served="no"
for _ in $(seq 1 20); do
  metrics="$(kubectl get --raw /api/v1/namespaces/tekton-pipelines/services/tekton-pipelines-controller:http-metrics/proxy/metrics 2>/dev/null)"
  case "$metrics" in
    *tekton_pipelines_controller_running_taskruns*) served="yes"; break ;;
  esac
  sleep 3
done
if [ "$served" != "yes" ]; then
  echo "FAIL: the controller does not serve tekton_pipelines_controller_running_taskruns on its http-metrics port. Restart it after changing config-observability."
  exit 1
fi

echo "PASS: the Tekton Pipelines controller serves its metrics in the Prometheus format."
exit 0
