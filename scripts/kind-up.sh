#!/usr/bin/env bash
# Create KIND cluster + ingress-nginx for Juice Shop AI.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
KIND_CONFIG="${KIND_CONFIG:-${ROOT_DIR}/kind-config.yaml}"
INGRESS_MANIFEST="${INGRESS_MANIFEST:-https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/kind/deploy.yaml}"

log() { printf '[kind-up] %s\n' "$*"; }

command -v kind >/dev/null || { echo "kind is required (brew install kind)" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }

mkdir -p "${ROOT_DIR}/data/kind/chromadb"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  log "Cluster '${CLUSTER_NAME}' already exists — skipping create"
else
  log "Creating KIND cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}" >/dev/null
log "Installing ingress-nginx for KIND..."
kubectl apply --context "kind-${CLUSTER_NAME}" -f "${INGRESS_MANIFEST}"

log "Waiting for ingress-nginx controller..."
kubectl --context "kind-${CLUSTER_NAME}" -n ingress-nginx wait \
  --for=condition=available deployment/ingress-nginx-controller \
  --timeout=180s

# Pods can lag slightly behind Deployment Available
for i in $(seq 1 36); do
  if kubectl --context "kind-${CLUSTER_NAME}" -n ingress-nginx get pods \
    -l app.kubernetes.io/component=controller \
    -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -q Running; then
    break
  fi
  sleep 5
done

kubectl --context "kind-${CLUSTER_NAME}" -n ingress-nginx wait \
  --for=condition=ready pod \
  -l app.kubernetes.io/component=controller \
  --timeout=180s

log "Cluster ready. Context: kind-${CLUSTER_NAME}"
log "HTTP ingress mapped to http://127.0.0.1:8080 (add '127.0.0.1 juiceshop-chatbot.local' to /etc/hosts)"
