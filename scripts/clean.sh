#!/usr/bin/env bash
# Safely reclaim local KIND / Docker disk without deleting source code or secrets.
# Usage:
#   make clean                 # prune dangling images + restart monitoring emptyDirs
#   CLEAN_CLUSTER=true make clean   # also delete KIND cluster
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="${CONTEXT:-kind-${CLUSTER_NAME}}"
CLEAN_CLUSTER="${CLEAN_CLUSTER:-false}"
CLEAN_MONITORING="${CLEAN_MONITORING:-true}"
CLEAN_DOCKER="${CLEAN_DOCKER:-true}"

log() { printf '[clean] %s\n' "$*"; }
warn() { printf '[clean] WARN: %s\n' "$*"; }

log "Safe local cleanup (source trees and .env secrets are never deleted)"

if [[ "${CLEAN_MONITORING}" == "true" ]] \
  && kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}" \
  && kubectl --context "${CONTEXT}" get ns monitoring >/dev/null 2>&1; then
  log "Restarting monitoring Deployments to drop emptyDir TSDB/log data..."
  for dep in prometheus grafana loki alertmanager; do
    kubectl --context "${CONTEXT}" -n monitoring rollout restart "deployment/${dep}" 2>/dev/null || true
  done
  kubectl --context "${CONTEXT}" -n monitoring rollout restart daemonset/promtail 2>/dev/null || true
fi

if [[ "${CLEAN_DOCKER}" == "true" ]] && command -v docker >/dev/null 2>&1; then
  log "Pruning dangling Docker images / build cache (unused only)..."
  docker image prune -f >/dev/null 2>&1 || warn "image prune skipped"
  docker builder prune -f >/dev/null 2>&1 || warn "builder prune skipped"
  # Do NOT run docker system prune -a — that would remove local :local images needed by KIND.
  log "Docker reclaim summary:"
  docker system df 2>/dev/null | sed 's/^/  /' || true
fi

# Optional: clear Chroma hostPath scratch (regenerated on next ingest)
if [[ "${CLEAN_CHROMA_DATA:-false}" == "true" ]]; then
  CHROMA_DIR="${ROOT_DIR}/data/kind/chromadb"
  if [[ -d "${CHROMA_DIR}" ]]; then
    log "Clearing ${CHROMA_DIR} (CLEAN_CHROMA_DATA=true)..."
    rm -rf "${CHROMA_DIR:?}/"*
  fi
fi

if [[ "${CLEAN_CLUSTER}" == "true" ]]; then
  log "Deleting KIND cluster '${CLUSTER_NAME}' (CLEAN_CLUSTER=true)..."
  kind delete cluster --name "${CLUSTER_NAME}" || warn "cluster delete failed"
else
  log "Kept KIND cluster (set CLEAN_CLUSTER=true to destroy)"
fi

log "Done. Next: make doctor && make monitoring (or make kind-up if cluster was deleted)"
