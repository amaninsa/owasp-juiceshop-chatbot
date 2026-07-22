#!/usr/bin/env bash
# Build images (if needed), load into KIND, apply manifests, wait for readiness.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="${NAMESPACE:-juiceshop-chatbot}"
K8S_DIR="${K8S_DIR:-${ROOT_DIR}/apps/overlays/local}"
ENV_OPENAI="${ENV_OPENAI:-${ROOT_DIR}/.env.openai}"
BUILD_IMAGES="${BUILD_IMAGES:-true}"

IMAGES=(
  "owasp-juiceshop-chatbot-chromadb:local"
  "owasp-juiceshop-chatbot-backend:local"
  "owasp-juiceshop-chatbot-frontend:local"
)

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }

command -v kind >/dev/null || die "kind is required"
command -v kubectl >/dev/null || die "kubectl is required"
command -v docker >/dev/null || die "docker is required"

kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}" \
  || die "Cluster '${CLUSTER_NAME}' not found. Run: make kind-up"

if [[ "${BUILD_IMAGES}" == "true" ]]; then
  log "Building local images via docker compose..."
  (
    cd "${ROOT_DIR}"
    docker compose build chromadb backend frontend
  )
fi

# Ensure juice-shop image has the expected local tag
if docker image inspect owasp-juiceshop-chatbot-frontend:local >/dev/null 2>&1; then
  :
elif docker image inspect juice-shop-juice-shop:latest >/dev/null 2>&1; then
  log "Tagging juice-shop-juice-shop:latest -> owasp-juiceshop-chatbot-frontend:local"
  docker tag juice-shop-juice-shop:latest owasp-juiceshop-chatbot-frontend:local
fi

for image in "${IMAGES[@]}"; do
  docker image inspect "${image}" >/dev/null 2>&1 || die "Missing image ${image}. Build first."
  log "Loading ${image} into KIND..."
  kind load docker-image "${image}" --name "${CLUSTER_NAME}"
done

log "Applying Kubernetes manifests..."
kubectl --context "${CONTEXT}" apply -k "${K8S_DIR}"

if [[ -f "${ENV_OPENAI}" ]]; then
  # shellcheck disable=SC1090
  set -a
  # Read KEY=VALUE without executing arbitrary shell
  OPEN_AI_KEY="$(grep -E '^OPEN_AI_KEY=' "${ENV_OPENAI}" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
  set +a
  if [[ -n "${OPEN_AI_KEY}" && "${OPEN_AI_KEY}" != "REPLACE_WITH_REAL_OPENAI_API_KEY" ]]; then
    log "Creating/updating OpenAI secret from ${ENV_OPENAI}"
    kubectl --context "${CONTEXT}" -n "${NAMESPACE}" create secret generic juiceshop-chatbot-secrets \
      --from-literal=OPEN_AI_KEY="${OPEN_AI_KEY}" \
      --dry-run=client -o yaml | kubectl --context "${CONTEXT}" apply -f -
  else
    log "WARNING: OPEN_AI_KEY missing/placeholder in ${ENV_OPENAI}"
  fi
else
  log "WARNING: ${ENV_OPENAI} not found — ensure secret juiceshop-chatbot-secrets exists"
fi

log "Waiting for deployments..."
kubectl --context "${CONTEXT}" -n "${NAMESPACE}" rollout status deployment/juiceshop-chatbot-chromadb --timeout=180s
kubectl --context "${CONTEXT}" -n "${NAMESPACE}" rollout status deployment/juiceshop-chatbot-backend --timeout=300s
kubectl --context "${CONTEXT}" -n "${NAMESPACE}" rollout status deployment/juiceshop-chatbot-frontend --timeout=180s

log "Deploy complete."
kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get pods,svc,ingress,pvc
log "Open: http://juiceshop-chatbot.local:8080  (or make port-forward)"
