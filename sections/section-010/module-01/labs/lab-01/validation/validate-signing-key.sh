#!/usr/bin/env bash
# PASS when the Secret signing-secrets in tekton-chains holds a cosign key
# pair: cosign.key, cosign.password and cosign.pub, all non-empty, and the
# private key is an encrypted PEM key.
set -uo pipefail

for key in cosign.key cosign.password cosign.pub; do
  value="$(kubectl -n tekton-chains get secret signing-secrets -o jsonpath="{.data.${key//./\\.}}" 2>/dev/null)"
  if [ -z "$value" ]; then
    echo "FAIL: the Secret signing-secrets in tekton-chains has no non-empty key $key."
    exit 1
  fi
done

private_key="$(kubectl -n tekton-chains get secret signing-secrets -o jsonpath='{.data.cosign\.key}' | base64 -d 2>/dev/null)"
case "$private_key" in
  *"ENCRYPTED"*"PRIVATE KEY"*) ;;
  *)
    echo "FAIL: cosign.key in signing-secrets is not an encrypted cosign private key. Create it with cosign generate-key-pair."
    exit 1 ;;
esac

echo "PASS: signing-secrets holds an encrypted cosign key pair with its password."
exit 0
