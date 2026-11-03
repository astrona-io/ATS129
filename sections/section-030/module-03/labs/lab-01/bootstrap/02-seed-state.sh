#!/usr/bin/env bash
# Creates the starting state for ats-129-lab-030-03.
#
# Applies the Task slow-check (the grader uses it to keep TaskRuns running) and
# waits for Alertmanager. Prometheus already evaluates the alerts and sends them
# to Alertmanager, which has one receiver and no routes. Writing the routes is
# the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"

for attempt in $(seq 1 30); do
  kubectl apply -f "$MANIFESTS/task-slow-check.yaml" && break
  echo "[lab] kubectl apply failed (attempt $attempt), retrying in 5s..."
  sleep 5
done
kubectl -n monitoring rollout status deployment/alertmanager --timeout=300s
echo "[lab] Starting state ready."
kubectl -n starfleet get tasks
