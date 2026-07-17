#!/usr/bin/env bash
# Quick status dump for KIND Juice Shop AI deployment.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-juiceshop-chatbot}"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="${NAMESPACE:-juiceshop-chatbot}"

kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get pods,svc,ingress,pvc,deploy -o wide
echo
kubectl --context "${CONTEXT}" -n "${NAMESPACE}" get events --sort-by=.lastTimestamp | tail -n 20 || true
