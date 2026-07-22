#!/usr/bin/env bash
# GitOps helper: set frontend/backend images in apps/overlays/local via kustomize edit.
# Usage:
#   OWNER=amaninsa TAG=$GITHUB_SHA ./scripts/gitops-set-images.sh
#   ./scripts/gitops-set-images.sh <tag> [owner]
#
# Image names (GHCR):
#   ghcr.io/<owner>/frontend:<tag>
#   ghcr.io/<owner>/backend:<tag>
#
# ChromaDB stays on the local KIND tag (not rewritten here).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-${TAG:-}}"
OWNER="${2:-${OWNER:-${GITHUB_REPOSITORY_OWNER:-amaninsa}}}"
OWNER="$(echo "${OWNER}" | tr '[:upper:]' '[:lower:]')"
REGISTRY="${REGISTRY:-ghcr.io}"
OVERLAY="${OVERLAY:-${ROOT_DIR}/apps/overlays/local}"

if [[ -z "${TAG}" ]]; then
  echo "ERROR: image tag required (arg1 or TAG=)" >&2
  exit 1
fi

command -v kustomize >/dev/null 2>&1 || {
  echo "ERROR: kustomize binary required (kustomize edit set image)" >&2
  exit 1
}

FRONTEND_IMG="${REGISTRY}/${OWNER}/frontend:${TAG}"
BACKEND_IMG="${REGISTRY}/${OWNER}/backend:${TAG}"

echo "Updating ${OVERLAY}"
echo "  frontend -> ${FRONTEND_IMG}"
echo "  backend  -> ${BACKEND_IMG}"
echo "  chromadb -> (unchanged — local KIND image)"

cd "${OVERLAY}"
kustomize edit set image \
  "owasp-juiceshop-chatbot-frontend=${FRONTEND_IMG}" \
  "owasp-juiceshop-chatbot-backend=${BACKEND_IMG}"

echo "Done. Review with: kubectl kustomize ${OVERLAY}"
