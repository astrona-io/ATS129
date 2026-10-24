#!/usr/bin/env bash
# PASS when a new TaskRun of release-image, started by the grader for its own
# image, is signed by Tekton Chains: cosign verifies its image signature and
# its SLSA v1.0 provenance with the release public key. This
# proves that the setup signs every build, not only build-bridge.
set -uo pipefail

NS="starfleet"
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

tag="grader-$(date +%s)"
manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<YAML
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: release-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  taskRef:
    name: release-image
  params:
    - name: image
      value: registry.localtest.me:5001/starfleet/probe
    - name: tag
      value: "$tag"
YAML

name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
if [ -z "$name" ]; then
  echo "FAIL: the grader could not create a TaskRun of the Task release-image."
  exit 1
fi

status=""
for _ in $(seq 1 60); do
  status="$(kubectl -n "$NS" get taskrun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
url="$(kubectl -n "$NS" get taskrun "$name" -o jsonpath='{.status.results[?(@.name=="IMAGE_URL")].value}' 2>/dev/null)"
digest="$(kubectl -n "$NS" get taskrun "$name" -o jsonpath='{.status.results[?(@.name=="IMAGE_DIGEST")].value}' 2>/dev/null)"
signed=""
[ "$status" = "True" ] && signed="$(wait_for_signed "$name")"
kubectl -n "$NS" delete taskrun "$name" --wait=false >/dev/null 2>&1 || true

if [ "$status" != "True" ]; then
  echo "FAIL: the grader TaskRun of release-image did not succeed (Succeeded=${status:-none})."
  exit 1
fi
if [ -z "$url" ] || [ -z "$digest" ]; then
  echo "FAIL: the grader TaskRun did not report the results IMAGE_URL and IMAGE_DIGEST."
  exit 1
fi
if [ "$signed" != "true" ]; then
  echo "FAIL: Tekton Chains marked the grader TaskRun chains.tekton.dev/signed='${signed}', expected 'true'."
  exit 1
fi

public_key="$(kubectl -n workstation get configmap lab-baseline-release-pub -o jsonpath='{.data.cosign\.pub}' 2>/dev/null)"
if [ -z "$public_key" ] || ! put_public_key "$public_key"; then
  echo "FAIL: could not load the release public key."
  exit 1
fi
ref="${url}@${digest}"
if ! verify_signature "$ref"; then
  echo "FAIL: the image of a grader TaskRun ($ref) has no signature that verifies with the release public key."
  exit 1
fi
if ! verify_provenance "$ref"; then
  echo "FAIL: the image of a grader TaskRun ($ref) has no SLSA v1.0 provenance that verifies with the release public key."
  exit 1
fi

echo "PASS: a new build of release-image was signed and attested automatically ($ref)."
exit 0
