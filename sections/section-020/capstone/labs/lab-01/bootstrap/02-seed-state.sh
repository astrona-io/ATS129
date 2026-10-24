#!/usr/bin/env bash
# Creates the starting state for ats-129-capstone-020.
#
# 1. Applies the Task nightly-check in starfleet and outpost and runs it
#    twice in each namespace.
# 2. Applies the starfleet pruning settings under a wrong ConfigMap name
#    (tekton-pruner-namespace-config) and without the config-type label.
# 3. Leaves the global configuration on enforcedConfigLevel: global.
# 4. Scales the Pruner webhook to zero. Its ValidatingWebhookConfiguration
#    has failurePolicy: Fail, so every change to a labelled Pruner ConfigMap
#    is refused until the webhook runs again.
#
# Finding and fixing the three faults is the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"

apply_with_retry() {
  # apply_with_retry FILE: the webhooks can refuse the first objects while they start.
  local attempt
  for attempt in $(seq 1 30); do
    kubectl apply -f "$1" && return 0
    echo "[lab] kubectl apply -f $1 failed (attempt $attempt), retrying in 5s..."
    sleep 5
  done
  return 1
}

# start_run NAMESPACE OUTCOME [PREFIX]: creates a TaskRun of nightly-check
# with generateName and prints its name.
start_run() {
  local manifest name
  manifest="$(mktemp)"
  cat > "$manifest" <<YAML
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: ${3:-nightly-grader}-
  namespace: $1
  labels:
    astrona.io/grader: "true"
spec:
  taskRef:
    name: nightly-check
  params:
    - name: outcome
      value: $2
YAML
  name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
  rm -f "$manifest"
  printf '%s' "$name"
}

# wait_for_end NAMESPACE NAME: waits up to 3 minutes until the run ended and
# prints its Succeeded status (True or False).
wait_for_end() {
  local status=""
  for _ in $(seq 1 60); do
    status="$(kubectl -n "$1" get taskrun "$2" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
    [ "$status" = "True" ] || [ "$status" = "False" ] && break
    sleep 3
  done
  printf '%s' "$status"
}

# ttl_annotation NAMESPACE NAME: prints the TTL the Pruner wrote on a run.
ttl_annotation() {
  kubectl -n "$1" get taskrun "$2" -o jsonpath='{.metadata.annotations.pruner\.tekton\.dev/ttlSecondsAfterFinished}' 2>/dev/null
}

# run_exists NAMESPACE NAME: exit 0 while the run still exists.
run_exists() {
  kubectl -n "$1" get taskrun "$2" >/dev/null 2>&1
}

apply_with_retry "$MANIFESTS/task-nightly-check.yaml"
for namespace in starfleet outpost; do
  for outcome in pass fail; do
    name="$(start_run "$namespace" "$outcome" nightly)"
    [ -n "$name" ] || { echo "ERROR: could not start a run in $namespace." >&2; exit 1; }
    status="$(wait_for_end "$namespace" "$name")"
    echo "[lab] $namespace/$name ended with Succeeded=${status:-unknown}."
  done
  kubectl -n "$namespace" label taskruns -l astrona.io/grader=true astrona.io/grader- >/dev/null
done

apply_with_retry "$MANIFESTS/configmap-pruner-wrong-name.yaml"

echo "[lab] Scaling the Pruner webhook to zero..."
kubectl -n tekton-pipelines scale deployment tekton-pruner-webhook --replicas=0
kubectl -n tekton-pipelines wait --for=delete pod -l app.kubernetes.io/part-of=tekton-pruner,app.kubernetes.io/component=webhook --timeout=120s || true

echo "[lab] Starting state ready."
kubectl get taskruns -n starfleet
kubectl get deployment -n tekton-pipelines
