#!/usr/bin/env bash
# Apply AppProject + App-of-Apps root (requires Argo CD CRDs).
# Usage: ./scripts/argocd-apply.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="${CONTEXT:-kind-${CLUSTER_NAME}}"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
ARGOCD_DIR="${ARGOCD_DIR:-${ROOT_DIR}/argocd}"

log() { printf '[argocd-apply] %s\n' "$*"; }
die() { printf '[argocd-apply] ERROR: %s\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null || die "kubectl is required"

K=(kubectl --context "${CONTEXT}")

if ! "${K[@]}" cluster-info >/dev/null 2>&1; then
  die "Cannot reach context '${CONTEXT}'. Run: make kind-up"
fi

if ! "${K[@]}" get crd applications.argoproj.io >/dev/null 2>&1 \
  || ! "${K[@]}" get crd appprojects.argoproj.io >/dev/null 2>&1; then
  die "Argo CD CRDs missing. Run: make argocd-install"
fi

# Wait until CRDs are Established (avoids race right after install)
"${K[@]}" wait --for=condition=Established crd/applications.argoproj.io --timeout=60s
"${K[@]}" wait --for=condition=Established crd/appprojects.argoproj.io --timeout=60s

if ! "${K[@]}" -n "${ARGOCD_NS}" get deploy argocd-server >/dev/null 2>&1; then
  die "argocd-server not found in ${ARGOCD_NS}. Run: make argocd-install"
fi

log "Applying AppProject + App-of-Apps root from ${ARGOCD_DIR}..."
"${K[@]}" apply -k "${ARGOCD_DIR}"

log "Waiting for root Application to be created..."
for i in $(seq 1 30); do
  if "${K[@]}" -n "${ARGOCD_NS}" get application juiceshop-chatbot-root >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

log "Current Applications:"
"${K[@]}" -n "${ARGOCD_NS}" get applications -o wide 2>/dev/null || true

cat <<EOF

[argocd-apply] Done.
  Root app  : juiceshop-chatbot-root  (path: argocd/apps)
  Children  : local / dev / prod / monitoring (synced by App-of-Apps)

  Note: child apps target Git overlays. For KIND local images, either:
    • keep using 'make deploy' for the app namespace, or
    • push images to GHCR and let Argo sync overlays/dev|prod

  Secrets are still out-of-band:
    kubectl -n juiceshop-chatbot create secret generic juiceshop-chatbot-secrets \\
      --from-literal=OPEN_AI_KEY="\$OPEN_AI_KEY" --dry-run=client -o yaml | kubectl apply -f -
EOF
