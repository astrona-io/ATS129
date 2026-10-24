#!/usr/bin/env bash
# PASS when the TaskRun build-bridge uses the Task build-image for
# registry.localtest.me:5001/starfleet/bridge:1.0.0, succeeded, reports the
# type-hinting results IMAGE_URL and IMAGE_DIGEST, was signed by Tekton
# Chains, and cosign verifies both the image signature and a SLSA v1.0
# provenance attestation with the public key in signing-secrets.
set -uo pipefail

NS="starfleet"
TR="build-bridge"
# ws CMD...: runs a command in the workstation pod (cosign, regctl, jq).
ws() { kubectl -n workstation exec deploy/workstation -- "$@"; }

# wait_for_signed NAME: waits up to 3 minutes for Tekton Chains to annotate
# the TaskRun, then prints the value of chains.tekton.dev/signed.
wait_for_signed() {
  local signed=""
  for _ in $(seq 1 60); do
    signed="$(kubectl -n starfleet get taskrun "$1" -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/signed}' 2>/dev/null)"
    [ "$signed" = "true" ] || [ "$signed" = "failed" ] && break
    sleep 3
  done
  printf '%s' "$signed"
}

# put_public_key PEM: writes a public key to /tmp/grader/cosign.pub in the
# workstation (passed as an environment variable, not through stdin).
put_public_key() {
  ws env PUB="$1" sh -c 'mkdir -p /tmp/grader && printf "%s\n" "$PUB" > /tmp/grader/cosign.pub && test -s /tmp/grader/cosign.pub'
}

# verify_signature REF: exit 0 when cosign verifies the image signature of
# REF (image@sha256:...) with /tmp/grader/cosign.pub.
verify_signature() {
  ws cosign verify --key /tmp/grader/cosign.pub --insecure-ignore-tlog --allow-http-registry "$1" >/dev/null 2>&1
}

# verify_provenance REF: exit 0 when cosign verifies a SLSA v1.0 provenance
# attestation of REF with /tmp/grader/cosign.pub.
verify_provenance() {
  ws cosign verify-attestation --key /tmp/grader/cosign.pub --insecure-ignore-tlog --allow-http-registry \
    --type slsaprovenance1 "$1" >/dev/null 2>&1
}

if ! kubectl -n "$NS" get taskrun "$TR" >/dev/null 2>&1; then
  echo "FAIL: TaskRun $TR does not exist in $NS."
  exit 1
fi
task_ref="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath='{.spec.taskRef.name}')"
image="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath='{.spec.params[?(@.name=="image")].value}')"
tag="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath='{.spec.params[?(@.name=="tag")].value}')"
if [ "$task_ref" != "build-image" ] || [ "$image" != "registry.localtest.me:5001/starfleet/bridge" ] || [ "$tag" != "1.0.0" ]; then
  echo "FAIL: TaskRun $TR must use taskRef build-image with image=registry.localtest.me:5001/starfleet/bridge and tag=1.0.0 (found taskRef='${task_ref}', image='${image}', tag='${tag}')."
  exit 1
fi

status="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
if [ "$status" != "True" ]; then
  echo "FAIL: TaskRun $TR has Succeeded=${status:-none}."
  exit 1
fi

url="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath='{.status.results[?(@.name=="IMAGE_URL")].value}')"
digest="$(kubectl -n "$NS" get taskrun "$TR" -o jsonpath='{.status.results[?(@.name=="IMAGE_DIGEST")].value}')"
if [ -z "$url" ] || ! [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "FAIL: TaskRun $TR must report IMAGE_URL and IMAGE_DIGEST (sha256:<64 hex>); found IMAGE_URL='${url}', IMAGE_DIGEST='${digest}'."
  exit 1
fi

signed="$(wait_for_signed "$TR")"
if [ "$signed" != "true" ]; then
  echo "FAIL: TaskRun $TR has chains.tekton.dev/signed='${signed}', expected 'true'. Create the TaskRun again after the fix."
  exit 1
fi

public_key="$(kubectl -n tekton-chains get secret signing-secrets -o jsonpath='{.data.cosign\.pub}' | base64 -d 2>/dev/null)"
if [ -z "$public_key" ] || ! put_public_key "$public_key"; then
  echo "FAIL: could not read cosign.pub from signing-secrets."
  exit 1
fi
ref="${url}@${digest}"
if ! verify_signature "$ref"; then
  echo "FAIL: cosign verify found no image signature for $ref that matches cosign.pub."
  exit 1
fi
if ! verify_provenance "$ref"; then
  echo "FAIL: cosign verify-attestation found no SLSA v1.0 provenance (slsaprovenance1) for $ref that matches cosign.pub."
  exit 1
fi

echo "PASS: $TR built $ref; its signature and its SLSA v1.0 provenance verify with cosign.pub."
exit 0
