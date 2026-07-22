#!/usr/bin/env bash
# Pre-flight checks for local KIND development (disk, tools, cluster health).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="${CONTEXT:-kind-${CLUSTER_NAME}}"
FAIL=0
WARN=0

ok()   { printf '  [OK]   %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; WARN=$((WARN + 1)); }
bad()  { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL + 1)); }

section() { printf '\n== %s ==\n' "$*"; }

section "Tools"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "Docker daemon reachable ($(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unknown))"
  else
    bad "Docker installed but daemon not reachable"
  fi
else
  bad "docker not found in PATH"
fi

if command -v kind >/dev/null 2>&1; then
  ok "kind $(kind version 2>/dev/null | head -1)"
else
  bad "kind not found in PATH"
fi

if command -v kubectl >/dev/null 2>&1; then
  ok "kubectl $(kubectl version --client -o yaml 2>/dev/null | awk '/gitVersion:/ {print $2; exit}')"
else
  bad "kubectl not found in PATH"
fi

section "Host disk"
if df -h / >/dev/null 2>&1; then
  AVAIL_LINE="$(df -h / | awk 'NR==2 {print $4" free of "$2" ("$5" used)"}')"
  PCT="$(df -P / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
  if [[ "${PCT}" -ge 90 ]]; then
    bad "Root disk critically full: ${AVAIL_LINE}"
  elif [[ "${PCT}" -ge 80 ]]; then
    warn "Root disk getting full: ${AVAIL_LINE}"
  else
    ok "Root disk: ${AVAIL_LINE}"
  fi
fi

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  ok "Docker disk usage (docker system df):"
  docker system df 2>/dev/null | sed 's/^/         /' || true
  if docker info 2>/dev/null | grep -qi 'docker desktop'; then
    ok "Docker Desktop detected (Apple Silicon: keep VM disk ≥ 40–60 GiB)"
  fi
fi

section "Host memory"
if command -v sysctl >/dev/null 2>&1; then
  MEM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || true)"
  if [[ -n "${MEM_BYTES}" ]]; then
    MEM_GB=$((MEM_BYTES / 1024 / 1024 / 1024))
    if [[ "${MEM_GB}" -lt 8 ]]; then
      warn "Host RAM ~${MEM_GB} GiB (recommend ≥ 8 GiB for app + monitoring + Argo CD)"
    else
      ok "Host RAM ~${MEM_GB} GiB"
    fi
  fi
elif command -v free >/dev/null 2>&1; then
  ok "Memory: $(free -h | awk '/Mem:/ {print $2" total, "$7" available"}')"
fi

section "KIND cluster"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  ok "Cluster '${CLUSTER_NAME}' exists"
  if kubectl --context "${CONTEXT}" get nodes >/dev/null 2>&1; then
    ok "kubectl context '${CONTEXT}' reachable"
    kubectl --context "${CONTEXT}" get nodes -o wide 2>/dev/null | sed 's/^/         /'
    NOT_READY="$(kubectl --context "${CONTEXT}" get nodes --no-headers 2>/dev/null | awk '$2!="Ready" {print}' | wc -l | tr -d ' ')"
    if [[ "${NOT_READY}" != "0" ]]; then
      bad "One or more nodes not Ready"
    fi
  else
    bad "Cannot reach context '${CONTEXT}'"
  fi
else
  warn "Cluster '${CLUSTER_NAME}' not found (run: make kind-up)"
fi

section "Namespaces & pods"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  for ns in juiceshop-chatbot monitoring argocd ingress-nginx; do
    if kubectl --context "${CONTEXT}" get ns "${ns}" >/dev/null 2>&1; then
      PENDING="$(kubectl --context "${CONTEXT}" -n "${ns}" get pods --no-headers 2>/dev/null \
        | awk '$3!~/Running|Completed|Succeeded/ {c++} END{print c+0}')"
      TOTAL="$(kubectl --context "${CONTEXT}" -n "${ns}" get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')"
      if [[ "${PENDING}" -gt 0 ]]; then
        warn "Namespace ${ns}: ${PENDING}/${TOTAL} pods not Running"
        kubectl --context "${CONTEXT}" -n "${ns}" get pods 2>/dev/null | sed 's/^/         /'
      else
        ok "Namespace ${ns}: ${TOTAL} pods healthy (or empty)"
      fi
    else
      ok "Namespace ${ns}: not created yet"
    fi
  done

  PRESSURE="$(kubectl --context "${CONTEXT}" get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" diskPressure="}{.status.conditions[?(@.type=="DiskPressure")].status}{"\n"}{end}' 2>/dev/null || true)"
  if echo "${PRESSURE}" | grep -q 'diskPressure=True'; then
    bad "Node DiskPressure=True — run: make clean"
  else
    ok "No DiskPressure on KIND node(s)"
  fi
fi

section "Ingress"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  if kubectl --context "${CONTEXT}" -n ingress-nginx get pods >/dev/null 2>&1; then
    ok "ingress-nginx namespace present"
    kubectl --context "${CONTEXT}" get ingress -A 2>/dev/null | sed 's/^/         /' || true
  else
    warn "ingress-nginx not found (run: make kind-up)"
  fi
fi

section "Monitoring"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}" \
  && kubectl --context "${CONTEXT}" get ns monitoring >/dev/null 2>&1; then
  for dep in prometheus grafana loki alertmanager; do
    if kubectl --context "${CONTEXT}" -n monitoring get deploy "${dep}" >/dev/null 2>&1; then
      READY="$(kubectl --context "${CONTEXT}" -n monitoring get deploy "${dep}" \
        -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null || echo '?/?')"
      ok "monitoring/${dep} ready ${READY}"
    else
      warn "monitoring/${dep} not deployed (run: make monitoring)"
    fi
  done
  if kubectl --context "${CONTEXT}" -n monitoring get ds cadvisor >/dev/null 2>&1; then
    warn "cAdvisor DaemonSet present (local profile normally deletes it to save disk/CPU)"
  else
    ok "cAdvisor absent (expected on local profile)"
  fi
else
  ok "Monitoring not deployed yet (optional: make monitoring)"
fi

section "Argo CD"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  if kubectl --context "${CONTEXT}" get crd applications.argoproj.io >/dev/null 2>&1; then
    ok "Argo CD CRDs registered"
    kubectl --context "${CONTEXT}" -n argocd get applications 2>/dev/null | sed 's/^/         /' || true
  else
    ok "Argo CD not installed yet (optional: make argocd-install)"
  fi
fi

section "GitHub Actions files"
WF="${ROOT_DIR}/.github/workflows"
if [[ -f "${WF}/platform-ci.yml" ]]; then
  ok "Found .github/workflows/platform-ci.yml"
else
  bad "Missing platform-ci.yml"
fi
for f in ci.yml codeql-analysis.yml; do
  if [[ -f "${WF}/${f}" ]]; then
    ok "Found .github/workflows/${f}"
  else
    warn "Optional workflow missing: ${f}"
  fi
done

section "Recommendations"
printf '  • Local monitoring: emptyDir + 24h retention (cAdvisor disabled)\n'
printf '  • Demo: make doctor && make demo && make urls\n'
printf '  • Expected RAM: ~6–10 GiB (app + monitoring + Argo CD)\n'
printf '  • Expected free disk on KIND node: ≥ 5–8 GiB\n'

printf '\n'
if [[ "${FAIL}" -gt 0 ]]; then
  printf 'doctor: %s failure(s), %s warning(s)\n' "${FAIL}" "${WARN}"
  exit 1
fi
printf 'doctor: all critical checks passed (%s warning(s))\n' "${WARN}"
exit 0
