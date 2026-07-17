#!/usr/bin/env bash
# Delete Juice Shop AI workloads (optionally destroy KIND cluster).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="${NAMESPACE:-juiceshop-chatbot}"
K8S_DIR="${K8S_DIR:-${ROOT_DIR}/apps/overlays/local}"
DELETE_CLUSTER="${DELETE_CLUSTER:-false}"

log() { printf '[delete] %s\n' "$*"; }

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  log "Cluster '${CLUSTER_NAME}' does not exist — nothing to delete"
  exit 0
fi

if kubectl --context "${CONTEXT}" get ns "${NAMESPACE}" >/dev/null 2>&1; then
  log "Deleting workloads via kustomize..."
  kubectl --context "${CONTEXT}" delete -k "${K8S_DIR}" --ignore-not-found=true || true
  # PV may remain due to Retain — clean explicitly for local loops
  kubectl --context "${CONTEXT}" delete pv juiceshop-chatbot-chromadb-pv --ignore-not-found=true || true
else
  log "Namespace ${NAMESPACE} already gone"
fi

if [[ "${DELETE_CLUSTER}" == "true" ]]; then
  log "Deleting KIND cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "${CLUSTER_NAME}"
fi

log "Done."
