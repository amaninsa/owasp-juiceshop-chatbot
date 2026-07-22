#!/usr/bin/env bash
# Install Argo CD (stable) into the KIND cluster and expose the UI.
# Usage: ./scripts/argocd-install.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="${CONTEXT:-kind-${CLUSTER_NAME}}"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
# Pin to a known stable release; override with ARGOCD_VERSION=v2.x.y if needed.
ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"
ARGOCD_MANIFEST="${ARGOCD_MANIFEST:-https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-300s}"

log() { printf '[argocd-install] %s\n' "$*"; }
die() { printf '[argocd-install] ERROR: %s\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null || die "kubectl is required"
command -v kind >/dev/null || die "kind is required"

kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}" \
  || die "Cluster '${CLUSTER_NAME}' not found. Run: make kind-up"

K=(kubectl --context "${CONTEXT}")

log "Creating namespace ${ARGOCD_NS}..."
"${K[@]}" create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | "${K[@]}" apply -f -

log "Installing Argo CD (${ARGOCD_VERSION}) — includes CRDs..."
# WHY server-side: Argo CD ApplicationSet CRD annotations exceed the
# 262144-byte client-side apply limit ("metadata.annotations: Too long").
"${K[@]}" apply --server-side --force-conflicts -n "${ARGOCD_NS}" -f "${ARGOCD_MANIFEST}"

log "Waiting for Application / AppProject CRDs..."
for i in $(seq 1 60); do
  if "${K[@]}" get crd applications.argoproj.io >/dev/null 2>&1 \
    && "${K[@]}" get crd appprojects.argoproj.io >/dev/null 2>&1; then
    log "CRDs are registered."
    break
  fi
  if [[ "$i" -eq 60 ]]; then
    die "Timed out waiting for Argo CD CRDs"
  fi
  sleep 2
done

# Ensure CRDs are Established before applying Applications
"${K[@]}" wait --for=condition=Established crd/applications.argoproj.io --timeout=120s
"${K[@]}" wait --for=condition=Established crd/appprojects.argoproj.io --timeout=120s

log "Waiting for Argo CD core deployments..."
for dep in argocd-redis argocd-repo-server argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-server; do
  if "${K[@]}" -n "${ARGOCD_NS}" get deploy "${dep}" >/dev/null 2>&1; then
    "${K[@]}" -n "${ARGOCD_NS}" rollout status "deployment/${dep}" --timeout="${WAIT_TIMEOUT}" || true
  fi
done

# application-controller is a StatefulSet in recent installs
if "${K[@]}" -n "${ARGOCD_NS}" get statefulset argocd-application-controller >/dev/null 2>&1; then
  "${K[@]}" -n "${ARGOCD_NS}" rollout status statefulset/argocd-application-controller --timeout="${WAIT_TIMEOUT}" || true
elif "${K[@]}" -n "${ARGOCD_NS}" get deploy argocd-application-controller >/dev/null 2>&1; then
  "${K[@]}" -n "${ARGOCD_NS}" rollout status deployment/argocd-application-controller --timeout="${WAIT_TIMEOUT}" || true
fi

log "Waiting for argocd-server Available..."
"${K[@]}" -n "${ARGOCD_NS}" wait --for=condition=available deployment/argocd-server --timeout="${WAIT_TIMEOUT}"

# Expose UI via existing ingress-nginx (KIND :8080)
if [[ -f "${ROOT_DIR}/argocd/ingress.yaml" ]]; then
  log "Applying Argo CD Ingress (argocd.juiceshop-chatbot.local)..."
  "${K[@]}" apply -f "${ROOT_DIR}/argocd/ingress.yaml"
fi

# Patch server for insecure mode behind local ingress (KIND only)
log "Configuring argocd-server for local ingress (insecure)..."
"${K[@]}" -n "${ARGOCD_NS}" patch configmap argocd-cmd-params-cm --type merge \
  -p '{"data":{"server.insecure":"true"}}' 2>/dev/null || true

# Local KIND: shrink repo-server cache / memory (GitOps behaviour unchanged).
if [[ -f "${ROOT_DIR}/argocd/patches/repo-server-local.yaml" ]]; then
  log "Applying local repo-server resource + parallelism patch..."
  "${K[@]}" -n "${ARGOCD_NS}" patch deployment argocd-repo-server --type strategic \
    --patch-file "${ROOT_DIR}/argocd/patches/repo-server-local.yaml"
fi

# Cap ephemeral volumes used by repo-server (tmp / gpg / plugins / helm).
# Does not remove upstream mounts — only sets emptyDir.sizeLimit when present.
log "Capping argocd-repo-server emptyDir sizeLimits..."
CONTEXT="${CONTEXT}" ARGOCD_NS="${ARGOCD_NS}" python3 - <<'PY' || true
import json, os, subprocess, sys
ctx = os.environ.get("CONTEXT", "kind-juiceshop-chatbot")
ns = os.environ.get("ARGOCD_NS", "argocd")
raw = subprocess.check_output(
    ["kubectl", "--context", ctx, "-n", ns, "get", "deploy", "argocd-repo-server", "-o", "json"],
    text=True,
)
dep = json.loads(raw)
limits = {
    "tmp": "256Mi",
    "var-files": "64Mi",
    "plugins": "64Mi",
    "gpg-keys": "16Mi",
    "gpg-keyring": "16Mi",
    "helm-working-dir": "128Mi",
}
changed = False
for vol in dep["spec"]["template"]["spec"].get("volumes", []):
    name = vol.get("name")
    if name in limits and "emptyDir" in vol:
        ed = dict(vol.get("emptyDir") or {})
        if ed.get("sizeLimit") != limits[name] or (
            name == "helm-working-dir" and ed.get("medium") != "Memory"
        ):
            ed["sizeLimit"] = limits[name]
            if name == "helm-working-dir":
                ed["medium"] = "Memory"
            vol["emptyDir"] = ed
            changed = True
if not changed:
    sys.exit(0)
patch = [{
    "op": "replace",
    "path": "/spec/template/spec/volumes",
    "value": dep["spec"]["template"]["spec"]["volumes"],
}]
subprocess.check_call(
    [
        "kubectl", "--context", ctx, "-n", ns, "patch", "deploy",
        "argocd-repo-server", "--type", "json", "-p", json.dumps(patch),
    ]
)
print("[argocd-install] repo-server emptyDir sizeLimits applied")
PY

if [[ -f "${ROOT_DIR}/argocd/patches/local-resources.yaml" ]]; then
  log "Applying local Argo CD resource limits..."
  "${K[@]}" apply -f "${ROOT_DIR}/argocd/patches/local-resources.yaml"
fi

# Soften reconciliation cadence on small local clusters
"${K[@]}" -n "${ARGOCD_NS}" patch configmap argocd-cm --type merge \
  -p '{"data":{"timeout.reconciliation":"180s"}}' \
  2>/dev/null || true

"${K[@]}" -n "${ARGOCD_NS}" rollout restart deployment/argocd-server
"${K[@]}" -n "${ARGOCD_NS}" rollout restart deployment/argocd-repo-server
"${K[@]}" -n "${ARGOCD_NS}" rollout status deployment/argocd-repo-server --timeout=180s || true
"${K[@]}" -n "${ARGOCD_NS}" rollout status deployment/argocd-server --timeout=180s

ADMIN_PASS="$("${K[@]}" -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode 2>/dev/null || true)"

log "Verifying installation..."
"${K[@]}" get crd applications.argoproj.io appprojects.argoproj.io >/dev/null
"${K[@]}" -n "${ARGOCD_NS}" get deploy,sts,svc,ingress 2>/dev/null || "${K[@]}" -n "${ARGOCD_NS}" get deploy,svc

cat <<EOF

============================================================
 Argo CD installed successfully
============================================================
 Namespace : ${ARGOCD_NS}
 Context   : ${CONTEXT}

 UI (Ingress — add to /etc/hosts):
   127.0.0.1 argocd.juiceshop-chatbot.local
   http://argocd.juiceshop-chatbot.local:8080

 UI (port-forward alternative):
   kubectl --context ${CONTEXT} -n ${ARGOCD_NS} port-forward svc/argocd-server 8081:80
   open http://127.0.0.1:8081

 Login:
   username : admin
   password : ${ADMIN_PASS:-<run: make argocd-password>}

 Next:
   make argocd-apply
============================================================
EOF
