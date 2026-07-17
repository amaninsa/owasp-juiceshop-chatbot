#!/usr/bin/env bash
# Validate Juice Shop AI platform deployment (K8s + optional HTTP checks).
# Usage:
#   ./scripts/validate.sh
#   SKIP_OPENAI=true ./scripts/validate.sh
#   FRONTEND_URL=http://juiceshop-chatbot.local:8080 BACKEND_URL=http://juiceshop-chatbot.local:8080/ai-assistant ./scripts/validate.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="${CONTEXT:-kind-${CLUSTER_NAME}}"
NAMESPACE="${NAMESPACE:-juiceshop-chatbot}"
FRONTEND_URL="${FRONTEND_URL:-}"
BACKEND_URL="${BACKEND_URL:-}"
SKIP_OPENAI="${SKIP_OPENAI:-false}"
ENV_OPENAI="${ENV_OPENAI:-${ROOT_DIR}/.env.openai}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"

PASS=0
FAIL=0
WARN=0

log() { printf '[validate] %s\n' "$*"; }
ok() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL + 1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$*"; WARN=$((WARN + 1)); }

die_prereq() {
  printf '[validate] ERROR: %s\n' "$*" >&2
  exit 2
}

command -v kubectl >/dev/null || die_prereq "kubectl is required"
command -v curl >/dev/null || die_prereq "curl is required"

if ! kubectl --context "${CONTEXT}" cluster-info >/dev/null 2>&1; then
  die_prereq "Cannot reach cluster context '${CONTEXT}'. Set CONTEXT=... or run make kind-up."
fi

K=(kubectl --context "${CONTEXT}" -n "${NAMESPACE}")

section() {
  printf '\n\033[1m== %s ==\033[0m\n' "$1"
}

wait_ready() {
  local kind="$1"
  local name="$2"
  if "${K[@]}" wait --for=condition=available "${kind}/${name}" --timeout="${TIMEOUT_SECONDS}s" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
section "Namespace"
# ---------------------------------------------------------------------------
if "${K[@]}" get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  ok "namespace ${NAMESPACE} exists"
else
  bad "namespace ${NAMESPACE} missing"
fi

# ---------------------------------------------------------------------------
section "Deployments"
# ---------------------------------------------------------------------------
for dep in juiceshop-chatbot-frontend juiceshop-chatbot-backend juiceshop-chatbot-chromadb; do
  if "${K[@]}" get deploy "${dep}" >/dev/null 2>&1; then
    ready="$("${K[@]}" get deploy "${dep}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
    desired="$("${K[@]}" get deploy "${dep}" -o jsonpath='{.status.replicas}' 2>/dev/null || echo 0)"
    ready="${ready:-0}"
    desired="${desired:-0}"
    if [[ "${ready}" -ge 1 && "${ready}" -eq "${desired}" ]]; then
      ok "deployment/${dep} ready (${ready}/${desired})"
    elif wait_ready deploy "${dep}"; then
      ok "deployment/${dep} became ready"
    else
      bad "deployment/${dep} not ready (ready=${ready} desired=${desired})"
    fi
  else
    bad "deployment/${dep} missing"
  fi
done

# ---------------------------------------------------------------------------
section "Pods"
# ---------------------------------------------------------------------------
not_running="$("${K[@]}" get pods --no-headers 2>/dev/null | awk '$3!="Running" && $3!="Completed" {print}' || true)"
if [[ -z "${not_running}" ]]; then
  count="$("${K[@]}" get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  ok "all pods Running (${count})"
else
  bad "pods not Running:"
  printf '%s\n' "${not_running}" | sed 's/^/         /'
fi

# ---------------------------------------------------------------------------
section "Services"
# ---------------------------------------------------------------------------
for svc in juiceshop-chatbot-frontend juiceshop-chatbot-backend juiceshop-chatbot-chromadb; do
  if "${K[@]}" get svc "${svc}" >/dev/null 2>&1; then
    port="$("${K[@]}" get svc "${svc}" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"
    ok "service/${svc} (port ${port})"
  else
    bad "service/${svc} missing"
  fi
done

# ---------------------------------------------------------------------------
section "Ingress"
# ---------------------------------------------------------------------------
if "${K[@]}" get ingress >/dev/null 2>&1; then
  ing_count="$("${K[@]}" get ingress --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${ing_count}" -ge 1 ]]; then
    ok "ingress resources present (${ing_count})"
    "${K[@]}" get ingress -o wide 2>/dev/null | sed 's/^/         /' || true
  else
    bad "no Ingress resources in ${NAMESPACE}"
  fi
else
  bad "cannot list Ingress"
fi

# ---------------------------------------------------------------------------
section "PVC"
# ---------------------------------------------------------------------------
if "${K[@]}" get pvc juiceshop-chatbot-chromadb-pvc >/dev/null 2>&1; then
  phase="$("${K[@]}" get pvc juiceshop-chatbot-chromadb-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo Unknown)"
  if [[ "${phase}" == "Bound" ]]; then
    ok "pvc/juiceshop-chatbot-chromadb-pvc Bound"
  else
    bad "pvc/juiceshop-chatbot-chromadb-pvc phase=${phase}"
  fi
else
  warn "pvc/juiceshop-chatbot-chromadb-pvc missing (Helm hostPath-less installs may differ)"
fi

# ---------------------------------------------------------------------------
section "Health checks (backend in-cluster)"
# ---------------------------------------------------------------------------
# Port-forward briefly for reliable checks without depending on Ingress DNS.
PF_PID=""
cleanup_pf() {
  if [[ -n "${PF_PID}" ]] && kill -0 "${PF_PID}" 2>/dev/null; then
    kill "${PF_PID}" >/dev/null 2>&1 || true
    wait "${PF_PID}" 2>/dev/null || true
  fi
}
trap cleanup_pf EXIT

LOCAL_BE_PORT="${LOCAL_BE_PORT:-18000}"
LOCAL_FE_PORT="${LOCAL_FE_PORT:-13000}"

"${K[@]}" port-forward svc/juiceshop-chatbot-backend "${LOCAL_BE_PORT}:8000" >/dev/null 2>&1 &
PF_PID=$!
sleep 2

if curl -fsS --max-time 5 "http://127.0.0.1:${LOCAL_BE_PORT}/livez" >/dev/null; then
  ok "backend /livez"
else
  bad "backend /livez"
fi

ready_code="$(curl -sS -o /tmp/js-ai-readyz.json -w '%{http_code}' --max-time 10 \
  "http://127.0.0.1:${LOCAL_BE_PORT}/readyz" || echo 000)"
if [[ "${ready_code}" == "200" ]]; then
  ok "backend /readyz"
else
  bad "backend /readyz (HTTP ${ready_code})"
fi

health_body="$(curl -fsS --max-time 10 "http://127.0.0.1:${LOCAL_BE_PORT}/health" || true)"
if echo "${health_body}" | grep -q '"status"'; then
  ok "backend /health → $(echo "${health_body}" | tr -d '\n' | cut -c1-120)"
else
  bad "backend /health"
fi

if curl -fsS --max-time 10 "http://127.0.0.1:${LOCAL_BE_PORT}/metrics" 2>/dev/null | grep -q 'juiceshop_chatbot_\|python_info\|process_'; then
  ok "backend /metrics"
else
  warn "backend /metrics missing — rebuild/redeploy backend image (Task 8+)"
fi

# ---------------------------------------------------------------------------
section "Vector DB (ChromaDB)"
# ---------------------------------------------------------------------------
cleanup_pf
PF_PID=""
"${K[@]}" port-forward svc/juiceshop-chatbot-chromadb "${LOCAL_BE_PORT}:8000" >/dev/null 2>&1 &
PF_PID=$!
sleep 2

if curl -fsS --max-time 5 "http://127.0.0.1:${LOCAL_BE_PORT}/api/v1/heartbeat" >/dev/null; then
  ok "chromadb /api/v1/heartbeat"
else
  bad "chromadb /api/v1/heartbeat"
fi

# ---------------------------------------------------------------------------
section "Frontend"
# ---------------------------------------------------------------------------
cleanup_pf
PF_PID=""
"${K[@]}" port-forward svc/juiceshop-chatbot-frontend "${LOCAL_FE_PORT}:3000" >/dev/null 2>&1 &
PF_PID=$!
sleep 2

fe_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
  "http://127.0.0.1:${LOCAL_FE_PORT}/" || echo 000)"
if [[ "${fe_code}" =~ ^2|3 ]]; then
  ok "frontend / (HTTP ${fe_code})"
else
  bad "frontend / (HTTP ${fe_code})"
fi

# Optional external URLs (Ingress)
if [[ -n "${FRONTEND_URL}" ]]; then
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${FRONTEND_URL}/" || echo 000)"
  if [[ "${code}" =~ ^2|3 ]]; then
    ok "FRONTEND_URL ${FRONTEND_URL}/ (HTTP ${code})"
  else
    bad "FRONTEND_URL ${FRONTEND_URL}/ (HTTP ${code})"
  fi
fi

if [[ -n "${BACKEND_URL}" ]]; then
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${BACKEND_URL}/livez" || echo 000)"
  if [[ "${code}" == "200" ]]; then
    ok "BACKEND_URL ${BACKEND_URL}/livez"
  else
    bad "BACKEND_URL ${BACKEND_URL}/livez (HTTP ${code})"
  fi
fi

# ---------------------------------------------------------------------------
section "OpenAI connectivity"
# ---------------------------------------------------------------------------
cleanup_pf
PF_PID=""

if [[ "${SKIP_OPENAI}" == "true" ]]; then
  warn "SKIP_OPENAI=true — skipped"
else
  # Prefer secret in cluster; fall back to local .env.openai
  KEY="$("${K[@]}" get secret juiceshop-chatbot-secrets -o jsonpath='{.data.OPEN_AI_KEY}' 2>/dev/null || true)"
  if [[ -n "${KEY}" ]]; then
    KEY="$(printf '%s' "${KEY}" | base64 --decode 2>/dev/null || printf '%s' "${KEY}" | base64 -D 2>/dev/null || true)"
  fi
  if [[ -z "${KEY}" && -f "${ENV_OPENAI}" ]]; then
    # shellcheck disable=SC1090
    set -a
    # Only export OPEN_AI_KEY if present
    KEY="$(grep -E '^OPEN_AI_KEY=' "${ENV_OPENAI}" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'" || true)"
    set +a
  fi

  if [[ -z "${KEY}" || "${KEY}" == "missing" || "${KEY}" == "REPLACE_WITH_REAL_OPENAI_API_KEY" ]]; then
    warn "no usable OPEN_AI_KEY — skipped live OpenAI check"
  else
    http_code="$(curl -sS -o /tmp/js-ai-openai.json -w '%{http_code}' --max-time 20 \
      https://api.openai.com/v1/models \
      -H "Authorization: Bearer ${KEY}" || echo 000)"
    if [[ "${http_code}" == "200" ]]; then
      ok "OpenAI API reachable (GET /v1/models)"
    else
      bad "OpenAI API HTTP ${http_code} (check key / network / NetworkPolicy egress)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
section "Summary"
# ---------------------------------------------------------------------------
log "PASS=${PASS} FAIL=${FAIL} WARN=${WARN}"
if [[ "${FAIL}" -gt 0 ]]; then
  log "Validation FAILED"
  exit 1
fi
log "Validation PASSED"
exit 0
