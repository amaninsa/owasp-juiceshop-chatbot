#!/usr/bin/env bash
# Port-forward frontend + backend for local access without /etc/hosts.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="${NAMESPACE:-juiceshop-chatbot}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
BACKEND_PORT="${BACKEND_PORT:-8000}"

log() { printf '[port-forward] %s\n' "$*"; }

cleanup() {
  log "Stopping port-forwards..."
  for pid in $(jobs -p); do
    kill "${pid}" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

log "Frontend  http://127.0.0.1:${FRONTEND_PORT}  -> svc/juiceshop-chatbot-frontend:3000"
kubectl --context "${CONTEXT}" -n "${NAMESPACE}" port-forward svc/juiceshop-chatbot-frontend "${FRONTEND_PORT}:3000" &

log "Backend   http://127.0.0.1:${BACKEND_PORT}  -> svc/juiceshop-chatbot-backend:8000"
kubectl --context "${CONTEXT}" -n "${NAMESPACE}" port-forward svc/juiceshop-chatbot-backend "${BACKEND_PORT}:8000" &

log "Press ctrl-c to stop"
wait
