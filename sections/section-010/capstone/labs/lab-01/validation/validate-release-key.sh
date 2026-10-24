#!/usr/bin/env bash
# PASS when signing-secrets still holds the team's release key (its
# cosign.pub matches the public key recorded when the capstone started) and
# cosign.password is the password that decrypts it. A new key pair fails
# here: the release key must stay.
set -uo pipefail

baseline="$(kubectl -n workstation get configmap lab-baseline-release-pub -o jsonpath='{.data.cosign\.pub}' 2>/dev/null)"
current="$(kubectl -n tekton-chains get secret signing-secrets -o jsonpath='{.data.cosign\.pub}' 2>/dev/null | base64 -d 2>/dev/null)"
if [ -z "$baseline" ]; then
  echo "FAIL: the grader baseline of the release public key is missing."
  exit 1
fi
if [ "$(printf '%s' "$current" | tr -d '\n')" != "$(printf '%s' "$baseline" | tr -d '\n')" ]; then
  echo "FAIL: cosign.pub in signing-secrets is not the release public key. Keep the release key pair; do not generate a new one."
  exit 1
fi

password="$(kubectl -n tekton-chains get secret signing-secrets -o jsonpath='{.data.cosign\.password}' 2>/dev/null | base64 -d 2>/dev/null)"
escrow="$(kubectl -n starfleet get secret release-key-escrow -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)"
if [ -z "$password" ] || [ "$password" != "$escrow" ]; then
  echo "FAIL: cosign.password in signing-secrets does not decrypt the release key. Use the password from the Secret release-key-escrow."
  exit 1
fi

echo "PASS: signing-secrets holds the release key with the password that decrypts it."
exit 0
