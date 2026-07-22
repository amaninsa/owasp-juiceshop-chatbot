# Troubleshooting Guide

## Application

| Symptom | Checks |
|---------|--------|
| Frontend 502 via ingress | `kubectl -n juiceshop-chatbot get pods,ingress`; ingress-nginx Ready? |
| Backend Init:0/1 forever | ChromaDB Ready? Init curl host must be `juiceshop-chatbot-chromadb` |
| `/chat` 502 | `OPEN_AI_KEY` secret present? Backend logs for OpenAI errors |
| `/metrics` missing | Rebuild backend image with `prometheus-client`; port-forward and curl |
| SQLite / ftp EROFS | Frontend Deployment must not use read-only root FS (local overlay) |

```bash
kubectl -n juiceshop-chatbot get pods
kubectl -n juiceshop-chatbot logs deploy/juiceshop-chatbot-backend --all-containers
kubectl -n juiceshop-chatbot describe pod -l app.kubernetes.io/component=backend
```

## NetworkPolicy

Prometheus scrape fails from `monitoring` → backend:

```bash
kubectl -n juiceshop-chatbot get networkpolicy
# Expect: juiceshop-chatbot-allow-prometheus-scrape
make monitoring   # reapplies NP from k8s/monitoring
```

## Observability

| Symptom | Checks |
|---------|--------|
| Grafana 404 | Hosts file + `:8080`; `kubectl -n monitoring get ingress` |
| Empty dashboards | Prometheus targets → `/targets`; backend job up? |
| No logs in Loki | `kubectl -n monitoring logs ds/promtail`; namespace keep regex |
| cAdvisor CrashLoop | KIND needs `automountServiceAccountToken: false` + containerd socket |

```bash
make monitoring-status
kubectl -n monitoring port-forward svc/prometheus 9090:9090
```

## CI / DevSecOps

| Symptom | Fix |
|---------|-----|
| Gitleaks fails | Remove real secrets; extend `.gitleaks.toml` allowlist only for training fixtures |
| Semgrep noisy | Tune rules / exclude paths; fix real findings in `backend/` |
| kubeconform unknown CRDs | Already skips `Application`/`AppProject`; ensure render path exists |
| Cosign fails | Workflow needs `id-token: write`; repo Actions OIDC enabled |
| GitOps commit no-op | No tag change detected; confirm `build-scan-push` succeeded |
| Duplicate workflows | Use **Platform CI/CD** only; legacy AI workflow is dispatch-only |

## GitOps / ArgoCD

| Symptom | Fix |
|---------|-----|
| `no matches for kind Application` | CRDs missing → `make argocd-install` then `make argocd-apply` |
| `metadata.annotations: Too long` | Install uses server-side apply (already in `argocd-install.sh`) |
| App stuck OutOfSync | `make argocd-status`; check prune/selfHeal |
| Wrong namespace | Dev→`juiceshop-chatbot-dev`, prod→`juiceshop-chatbot-prod`, local→`juiceshop-chatbot` |
| Root app healthy, children missing | Wait for sync; ensure Git repoURL reachable |
| ImagePullBackOff | GHCR visibility; `imagePullSecrets` for private packages |

```bash
make argocd-install
make argocd-apply
make argocd-status
kubectl -n argocd get applications
```

## KIND / Docker

| Symptom | Fix |
|---------|-----|
| `ENOSPC` during build | `docker system prune`; increase Colima disk |
| `permission denied` docker.sock | Start Colima; check context `docker context use colima` |
| Ingress not on 8080 | `kind-config.yaml` extraPortMappings; recreate cluster |

## Useful one-liners

```bash
make status
make validate
make monitoring-status
kubectl get applications -n argocd -o wide
curl -fsS -H 'Host: juiceshop-chatbot.local' http://127.0.0.1:8080/ | head
```
