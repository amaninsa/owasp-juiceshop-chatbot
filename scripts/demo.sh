#!/usr/bin/env bash
# Interview / LinkedIn demo helper — prints cluster state + URLs.
# Usage: make demo   OR   ./scripts/demo.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="${CONTEXT:-kind-${CLUSTER_NAME}}"
K=(kubectl --context "${CONTEXT}")

banner() {
  printf '\n\033[1;36m== %s ==\033[0m\n' "$*"
}

run() {
  printf '\033[0;33m$ %s\033[0m\n' "$*"
  # shellcheck disable=SC2086
  eval "$@" || true
  echo
}

banner "Juice Shop AI — Cloud Native Platform Demo"
printf 'Cluster context: %s\n' "${CONTEXT}"
printf 'Tip: walk this output while narrating docs/demo-script.md\n'

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  printf '\n[ERROR] KIND cluster "%s" not found. Run: make kind-up && make deploy\n' "${CLUSTER_NAME}"
  exit 1
fi

banner "1. Cluster nodes"
run "${K[*]} get nodes -o wide"

banner "2. Pods (all namespaces)"
run "${K[*]} get pods -A"

banner "3. Services (all namespaces)"
run "${K[*]} get svc -A"

banner "4. Ingress"
run "${K[*]} get ingress -A"

banner "5. Deployments"
run "${K[*]} get deployments -A"

banner "6. Argo CD Applications"
if "${K[@]}" get crd applications.argoproj.io >/dev/null 2>&1; then
  run "${K[*]} get applications -n argocd"
else
  printf 'Argo CD not installed yet — run: make argocd-install && make argocd-apply\n\n'
fi

banner "7. Resource usage (if metrics-server present)"
if "${K[@]}" top pods -A >/dev/null 2>&1; then
  run "${K[*]} top pods -A"
else
  printf 'kubectl top not available (metrics-server optional on KIND) — skipping\n\n'
fi

banner "8. Demo URLs"
chmod +x "${ROOT_DIR}/scripts/urls.sh"
"${ROOT_DIR}/scripts/urls.sh"

banner "Next talking points"
cat <<'EOF'
  • Open the AI app → ask a product question (RAG)
  • Prometheus → Status → Targets (backend UP)
  • Grafana → Cluster Overview + AI Assistant dashboards
  • Grafana Explore → Loki (app logs)
  • Alertmanager → active/silenced alerts
  • Argo CD → App of Apps, sync, self-heal
  • GitHub → Actions → Platform CI/CD

Full script: docs/demo-script.md
10-minute guide: docs/demo.md
EOF
