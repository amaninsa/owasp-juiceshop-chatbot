#!/usr/bin/env bash
# Print demo / portfolio URLs for the Juice Shop AI platform (KIND ingress :8080).
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/amaninsa/owasp-juiceshop-chatbot}"
PORT="${INGRESS_PORT:-8080}"

cat <<EOF

============================================================
 Juice Shop AI — Demo URLs (KIND ingress → :${PORT})
============================================================

  AI Application   http://juiceshop-chatbot.local:${PORT}
  Grafana          http://grafana.juiceshop-chatbot.local:${PORT}
  Prometheus       http://prometheus.juiceshop-chatbot.local:${PORT}
  Alertmanager     http://alertmanager.juiceshop-chatbot.local:${PORT}
  Argo CD          http://argocd.juiceshop-chatbot.local:${PORT}
  Loki             (in-cluster only — use Grafana Explore or port-forward)

  GitHub Repository
    ${REPO_URL}

  GitHub Actions
    ${REPO_URL}/actions

------------------------------------------------------------
 /etc/hosts (add if missing):

  127.0.0.1 juiceshop-chatbot.local
  127.0.0.1 grafana.juiceshop-chatbot.local
  127.0.0.1 prometheus.juiceshop-chatbot.local
  127.0.0.1 alertmanager.juiceshop-chatbot.local
  127.0.0.1 argocd.juiceshop-chatbot.local

 Grafana login: admin / admin  (anonymous Viewer enabled)
 Argo CD login: admin / \$(make argocd-password)
============================================================

EOF
