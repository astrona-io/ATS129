#!/usr/bin/env bash
# Installs the environment for ats-129-playground-030-01.
#
# Playground preparation only. There is no task and no grading.
# This script:
#   1. puts the tkn command-line tool (pinned) on the PATH,
#   2. applies lab-start.yaml (namespaces and helper workloads),
#   3. installs Tekton Pipelines v1.17.1 from the release manifest and waits for the webhook.
set -euo pipefail

TKN_VERSION="0.46.2"
PIPELINES_VERSION="v1.17.1"
CHAINS_VERSION="v0.29.9"
PRUNER_VERSION="v0.4.4"
OPERATOR_VERSION="v0.81.2"
INSTALL_PIPELINES="yes"   # yes or no
INSTALL_CHAINS="yes"        # yes or no
INSTALL_PRUNER="yes"        # yes or no
INSTALL_OPERATOR="no"     # yes or no (the Operator only, no TektonConfig)
SIGNING_TOOLS="no"         # yes: registry and workstation pod in lab-start.yaml
LOG="[playground]"
REGISTRY_HOST="registry.localtest.me"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

# Pin the version rather than accepting whatever tkn happens to be on the
# machine: the course is written against tkn ${TKN_VERSION}.
have_version=""
if command -v tkn >/dev/null 2>&1; then
  have_version="$(tkn version --component client 2>/dev/null || true)"
  have_version="${have_version#v}"
fi
if [ "$have_version" != "$TKN_VERSION" ]; then
  case "$(uname -s)" in
    Darwin) TKN_OS="Darwin"; TKN_ARCH="all" ;;
    Linux)
      TKN_OS="Linux"
      case "$(uname -m)" in
        x86_64|amd64) TKN_ARCH="x86_64" ;;
        aarch64|arm64) TKN_ARCH="aarch64" ;;
        *) echo "ERROR: no tkn release for $(uname -m)." >&2; exit 1 ;;
      esac ;;
    *) echo "ERROR: no tkn release for $(uname -s)." >&2; exit 1 ;;
  esac
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  echo "$LOG Downloading tkn ${TKN_VERSION} (${TKN_OS}/${TKN_ARCH})..."
  curl -fsSL -o "$WORK/tkn.tar.gz" \
    "https://github.com/tektoncd/cli/releases/download/v${TKN_VERSION}/tkn_${TKN_VERSION}_${TKN_OS}_${TKN_ARCH}.tar.gz"
  tar -xzf "$WORK/tkn.tar.gz" -C "$WORK" tkn
  install -m 0755 "$WORK/tkn" "$BIN_DIR/tkn"
fi
echo "$LOG tkn client version: $(tkn version --component client)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR=""
for candidate in "$SCRIPT_DIR/../manifests" "./manifests" "$SCRIPT_DIR/manifests"; do
  [ -d "$candidate" ] && { MANIFEST_DIR="$candidate"; break; }
done
[ -n "$MANIFEST_DIR" ] || { echo "ERROR: manifests folder not found." >&2; exit 1; }

apply_with_retry() {
  # apply_with_retry ARGS...: kubectl apply, retried while the API server or
  # a webhook is still starting.
  local attempt
  for attempt in $(seq 1 30); do
    if kubectl apply "$@"; then
      return 0
    fi
    echo "$LOG kubectl apply failed (attempt $attempt), retrying in 5s..."
    sleep 5
  done
  echo "ERROR: kubectl apply $* kept failing." >&2
  return 1
}

wait_for_tekton_webhook() {
  # The webhook validates every Tekton object. A Deployment can be Available a
  # moment before its Service answers, so retry a server-side dry run of a
  # small Task until the webhook accepts it.
  local probe attempt
  probe="$(mktemp)"
  cat > "$probe" <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: webhook-probe
  namespace: starfleet
spec:
  steps:
    - name: probe
      image: busybox:1.37.0
      script: |
        echo probe
YAML
  for attempt in $(seq 1 60); do
    if kubectl apply --dry-run=server -f "$probe" >/dev/null 2>&1; then
      rm -f "$probe"
      echo "$LOG The Tekton webhook answers."
      return 0
    fi
    sleep 5
  done
  rm -f "$probe"
  echo "ERROR: the Tekton webhook did not accept a Task within 5 minutes." >&2
  return 1
}

wait_for_pruner_webhook() {
  # The Pruner webhook validates the labelled pruner ConfigMaps
  # (failurePolicy: Fail). Retry a server-side dry run of a label change on
  # the global ConfigMap until the webhook answers.
  local attempt
  for attempt in $(seq 1 60); do
    if kubectl -n tekton-pipelines label configmap tekton-pruner-default-spec \
      astrona.io/probe=ready --overwrite --dry-run=server >/dev/null 2>&1; then
      echo "$LOG The Pruner webhook answers."
      return 0
    fi
    sleep 5
  done
  echo "ERROR: the Pruner webhook did not answer within 5 minutes." >&2
  return 1
}

if [ "$SIGNING_TOOLS" = "yes" ]; then
  # One name for the registry everywhere in the cluster. The answer is
  # rewritten back to the asked name: Go programs (cosign, the Chains
  # controller) ignore DNS answers whose name differs from the question.
  corefile="$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}')"
  case "$corefile" in
    *"$REGISTRY_HOST"*) ;;
    *)
      echo "$LOG Adding the CoreDNS rewrite for ${REGISTRY_HOST}..."
      new_corefile="$(printf '%s\n' "$corefile" | awk '/^[[:space:]]*kubernetes / && !done {
          print "    rewrite stop {"
          print "        name regex registry\\.localtest\\.me registry.registry.svc.cluster.local"
          print "        answer name registry\\.registry\\.svc\\.cluster\\.local registry.localtest.me"
          print "    }"
          done=1
        } {print}')"
      kubectl -n kube-system create configmap coredns --from-literal=Corefile="$new_corefile" \
        --dry-run=client -o yaml | kubectl apply -f -
      kubectl -n kube-system rollout restart deployment/coredns
      kubectl -n kube-system rollout status deployment/coredns --timeout=180s
      ;;
  esac
fi

# lab-start.yaml is also listed under bootstrap.manifests in config.yaml, so it
# may already be applied. kubectl apply is idempotent.
apply_with_retry -f "$MANIFEST_DIR/lab-start.yaml"

if [ "$INSTALL_PIPELINES" = "yes" ]; then
  echo "$LOG Installing Tekton Pipelines ${PIPELINES_VERSION}..."
  apply_with_retry -f "https://infra.tekton.dev/tekton-releases/pipeline/previous/${PIPELINES_VERSION}/release.yaml"
  for deployment in tekton-pipelines-controller tekton-pipelines-webhook tekton-events-controller; do
    kubectl -n tekton-pipelines rollout status "deployment/$deployment" --timeout=300s
  done
  kubectl -n tekton-pipelines-resolvers rollout status deployment/tekton-pipelines-remote-resolvers --timeout=300s
  wait_for_tekton_webhook
fi

if [ "$INSTALL_CHAINS" = "yes" ]; then
  echo "$LOG Installing Tekton Chains ${CHAINS_VERSION}..."
  apply_with_retry -f "https://infra.tekton.dev/tekton-releases/chains/previous/${CHAINS_VERSION}/release.yaml"
  kubectl -n tekton-chains rollout status deployment/tekton-chains-controller --timeout=300s
  if [ -f "$MANIFEST_DIR/workstation-access.yaml" ]; then
    apply_with_retry -f "$MANIFEST_DIR/workstation-access.yaml"
  fi
fi

if [ "$INSTALL_PRUNER" = "yes" ]; then
  echo "$LOG Installing the Tekton Pruner ${PRUNER_VERSION}..."
  apply_with_retry -f "https://infra.tekton.dev/tekton-releases/pruner/previous/${PRUNER_VERSION}/release.yaml"
  for deployment in tekton-pruner-controller tekton-pruner-webhook; do
    kubectl -n tekton-pipelines rollout status "deployment/$deployment" --timeout=300s
  done
  wait_for_pruner_webhook
fi

if [ "$INSTALL_OPERATOR" = "yes" ]; then
  echo "$LOG Installing the Tekton Operator ${OPERATOR_VERSION} (without the default TektonConfig)..."
  operator_dir="$(mktemp -d)"
  curl -fsSL -o "$operator_dir/release.yaml" \
    "https://infra.tekton.dev/tekton-releases/operator/previous/${OPERATOR_VERSION}/release.yaml"
  # The release turns AUTOINSTALL_COMPONENTS on, which makes the Operator
  # create a TektonConfig with the profile "all" at once. The playground
  # leaves that step to the reader, so switch it off before applying.
  sed 's/AUTOINSTALL_COMPONENTS: "true"/AUTOINSTALL_COMPONENTS: "false"/' \
    "$operator_dir/release.yaml" > "$operator_dir/release-noauto.yaml"
  apply_with_retry -f "$operator_dir/release-noauto.yaml"
  rm -rf "$operator_dir"
  for deployment in tekton-operator tekton-operator-webhook; do
    kubectl -n tekton-operator rollout status "deployment/$deployment" --timeout=300s
  done
fi

if [ "$SIGNING_TOOLS" = "yes" ]; then
  echo "$LOG Waiting for the registry and the workstation pod..."
  kubectl -n registry rollout status deployment/registry --timeout=300s
  kubectl -n workstation rollout status deployment/workstation --timeout=600s
  tools_ready="no"
  for _ in $(seq 1 60); do
    if kubectl -n workstation exec deploy/workstation -- sh -c 'command -v cosign >/dev/null && command -v regctl >/dev/null && command -v jq >/dev/null' >/dev/null 2>&1; then
      tools_ready="yes"
      break
    fi
    sleep 5
  done
  [ "$tools_ready" = "yes" ] || { echo "ERROR: the workstation tools are not ready." >&2; exit 1; }
  registry_ready="no"
  for _ in $(seq 1 60); do
    if kubectl -n workstation exec deploy/workstation -- curl -fsS "http://${REGISTRY_HOST}:5001/v2/" >/dev/null 2>&1; then
      registry_ready="yes"
      break
    fi
    sleep 5
  done
  [ "$registry_ready" = "yes" ] || { echo "ERROR: the registry does not answer at ${REGISTRY_HOST}:5001." >&2; exit 1; }
fi

if kubectl get namespace monitoring >/dev/null 2>&1; then
  for deployment in $(kubectl -n monitoring get deployment -o name); do
    kubectl -n monitoring rollout status "$deployment" --timeout=300s
  done
fi

echo "$LOG Environment ready."
