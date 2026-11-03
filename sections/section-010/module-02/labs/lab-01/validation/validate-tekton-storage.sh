#!/usr/bin/env bash
# PASS when the TaskRun build-bridge carries the Chains annotations for a
# payload and a signature in the tekton storage, and the payload is a
# SLSA v1.0 provenance statement.
set -uo pipefail

NS="starfleet"
TR="build-bridge"

if ! kubectl -n "$NS" get taskrun "$TR" >/dev/null 2>&1; then
  echo "FAIL: TaskRun $TR does not exist in $NS."
  exit 1
fi

signed=""
for _ in $(seq 1 60); do
  signed="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}' 2>/dev/null)"
  [ "$signed" = "true" ] || [ "$signed" = "failed" ] && break
  sleep 3
done
if [ "$signed" != "true" ]; then
  echo "FAIL: TaskRun $TR has chains.tekton.dev/signed='${signed}', expected 'true'. Create the TaskRun again after the change."
  exit 1
fi

uid="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath='{.metadata.uid}')"
payload="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/payload-taskrun-${uid}}")"
signature="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-${uid}}")"
if [ -z "$payload" ] || [ -z "$signature" ]; then
  echo "FAIL: TaskRun $TR has no payload-taskrun-${uid} and signature-taskrun-${uid} annotations. Add tekton to artifacts.taskrun.storage and create the TaskRun again."
  exit 1
fi

predicate="$(printf '%s' "$payload" | base64 -d 2>/dev/null | kubectl -n workstation exec -i deploy/workstation -- jq -r '.predicateType' 2>/dev/null)"
if [ "$predicate" != "https://slsa.dev/provenance/v1" ]; then
  echo "FAIL: the payload annotation of $TR has predicateType '${predicate}', expected 'https://slsa.dev/provenance/v1' (format slsa/v2alpha4)."
  exit 1
fi

echo "PASS: $TR holds a signed SLSA v1.0 provenance payload in its annotations."
exit 0
