#!/usr/bin/env bash
# Tail logs for Juice Shop AI workloads.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="${NAMESPACE:-juiceshop-chatbot}"
COMPONENT="${1:-all}"
FOLLOW="${FOLLOW:-true}"

log() { printf '[logs] %s\n' "$*"; }

follow_args=()
if [[ "${FOLLOW}" == "true" ]]; then
  follow_args+=(-f)
fi

case "${COMPONENT}" in
  all)
    log "Streaming logs for all app pods (ctrl-c to stop)..."
    kubectl --context "${CONTEXT}" -n "${NAMESPACE}" logs \
      --selector='app.kubernetes.io/part-of=juiceshop-chatbot' \
      --all-containers=true \
      --prefix=true \
      --max-log-requests=20 \
      "${follow_args[@]}"
    ;;
  backend|frontend|chromadb|vector-db)
    selector="app.kubernetes.io/component=${COMPONENT}"
    if [[ "${COMPONENT}" == "chromadb" ]]; then
      selector="app.kubernetes.io/component=vector-db"
    fi
    log "Streaming logs for ${selector}..."
    kubectl --context "${CONTEXT}" -n "${NAMESPACE}" logs \
      --selector="${selector}" \
      --all-containers=true \
      --prefix=true \
      "${follow_args[@]}"
    ;;
  *)
    echo "Usage: $0 [all|backend|frontend|chromadb]" >&2
    exit 1
    ;;
esac
