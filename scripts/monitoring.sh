#!/usr/bin/env bash
# Deploy / manage the local KIND observability stack (k8s/monitoring).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="${CONTEXT:-kind-${CLUSTER_NAME}}"
# Profiles: local (default, emptyDir/24h) | production (PVC/long retention)
MONITORING_PROFILE="${MONITORING_PROFILE:-local}"
case "${MONITORING_PROFILE}" in
  local|production) ;;
  *)
    printf '[monitoring] ERROR: MONITORING_PROFILE must be local|production (got %s)\n' \
      "${MONITORING_PROFILE}" >&2
    exit 1
    ;;
esac
MONITORING_DIR="${MONITORING_DIR:-${ROOT_DIR}/k8s/monitoring/${MONITORING_PROFILE}}"
NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
ACTION="${1:-deploy}"

log() { printf '[monitoring] %s\n' "$*"; }
die() { printf '[monitoring] ERROR: %s\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null || die "kubectl is required"
command -v kind >/dev/null || die "kind is required"

kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}" \
  || die "Cluster '${CLUSTER_NAME}' not found. Run: make kind-up"

K=(kubectl --context "${CONTEXT}")

ensure_hosts_hint() {
  log "Add these hosts (if missing) to /etc/hosts pointing at 127.0.0.1:"
  log "  grafana.juiceshop-chatbot.local"
  log "  prometheus.juiceshop-chatbot.local"
  log "  alertmanager.juiceshop-chatbot.local"
  log "KIND ingress is on http://127.0.0.1:8080"
}

case "${ACTION}" in
  deploy|apply)
    # Scrape NetworkPolicy targets the app namespace — ensure it exists.
    "${K[@]}" create namespace juiceshop-chatbot --dry-run=client -o yaml | "${K[@]}" apply -f -
    log "Applying observability stack (profile=${MONITORING_PROFILE}) from ${MONITORING_DIR}..."
    "${K[@]}" apply -k "${MONITORING_DIR}"

    # NetworkPolicy lives in juiceshop-chatbot ns (resource file sets namespace)
    log "Waiting for core monitoring deployments..."
    "${K[@]}" -n "${NAMESPACE}" rollout status deployment/prometheus --timeout=180s
    "${K[@]}" -n "${NAMESPACE}" rollout status deployment/alertmanager --timeout=120s
    "${K[@]}" -n "${NAMESPACE}" rollout status deployment/kube-state-metrics --timeout=120s
    "${K[@]}" -n "${NAMESPACE}" rollout status deployment/loki --timeout=180s
    "${K[@]}" -n "${NAMESPACE}" rollout status deployment/grafana --timeout=180s

    log "Waiting for DaemonSets..."
    "${K[@]}" -n "${NAMESPACE}" rollout status daemonset/node-exporter --timeout=180s || true
    "${K[@]}" -n "${NAMESPACE}" rollout status daemonset/cadvisor --timeout=180s || true
    "${K[@]}" -n "${NAMESPACE}" rollout status daemonset/promtail --timeout=180s || true

    ensure_hosts_hint
    log "Deploy complete."
    "${K[@]}" -n "${NAMESPACE}" get pods,svc,ingress
    ;;

  delete|destroy)
    log "Deleting observability stack..."
    "${K[@]}" delete -k "${MONITORING_DIR}" --ignore-not-found=true
    # Explicitly remove scrape NetworkPolicy in app namespace if orphaned
    "${K[@]}" -n juiceshop-chatbot delete networkpolicy juiceshop-chatbot-allow-prometheus-scrape --ignore-not-found=true
    log "Monitoring stack deleted."
    ;;

  status)
    log "Namespace: ${NAMESPACE}"
    "${K[@]}" -n "${NAMESPACE}" get pods,svc,ingress,daemonset,deploy 2>/dev/null || true
    echo
    log "Prometheus targets (sample):"
    "${K[@]}" -n "${NAMESPACE}" exec deploy/prometheus -- \
      wget -qO- http://127.0.0.1:9090/api/v1/targets 2>/dev/null \
      | head -c 2000 || log "(prometheus not ready or wget unavailable)"
    echo
    log "App scrape NetworkPolicy:"
    "${K[@]}" -n juiceshop-chatbot get networkpolicy juiceshop-chatbot-allow-prometheus-scrape 2>/dev/null || true
    ;;

  port-forward|pf)
    log "Port-forwarding Grafana:3001 Prometheus:9090 Alertmanager:9093 Loki:3100"
    log "Ctrl+C to stop."
    "${K[@]}" -n "${NAMESPACE}" port-forward svc/grafana 3001:3000 &
    PF1=$!
    "${K[@]}" -n "${NAMESPACE}" port-forward svc/prometheus 9090:9090 &
    PF2=$!
    "${K[@]}" -n "${NAMESPACE}" port-forward svc/alertmanager 9093:9093 &
    PF3=$!
    "${K[@]}" -n "${NAMESPACE}" port-forward svc/loki 3100:3100 &
    PF4=$!
    trap 'kill ${PF1} ${PF2} ${PF3} ${PF4} 2>/dev/null || true' EXIT INT TERM
    wait
    ;;

  *)
    die "Unknown action '${ACTION}'. Use: deploy|delete|status|port-forward"
    ;;
esac
