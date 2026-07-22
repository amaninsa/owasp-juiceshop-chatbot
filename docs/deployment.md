# Deployment Guide

## Paths

| Path | When to use |
|------|-------------|
| **Docker Compose** | Laptop demo of full stack + gateway |
| **KIND + Make** | Local Kubernetes without ArgoCD |
| **KIND + ArgoCD** | GitOps practice / CI parity |
| **EKS + ArgoCD** | Production cloud (same overlays) |

## 1) Docker Compose (fastest)

```bash
# .env.openai with OPEN_AI_KEY=...
docker compose up --build -d
# Gateway: http://localhost:3000
```

## 2) KIND (imperative)

```bash
make kind-up
make deploy          # build/load images + apps/overlays/local
make monitoring      # optional observability
make validate
```

Hosts (`/etc/hosts`):

```text
127.0.0.1 juiceshop-chatbot.local
127.0.0.1 grafana.juiceshop-chatbot.local
127.0.0.1 prometheus.juiceshop-chatbot.local
127.0.0.1 alertmanager.juiceshop-chatbot.local
```

App: http://juiceshop-chatbot.local:8080

## 3) KIND + ArgoCD (GitOps)

```bash
make kind-up
# Install ArgoCD (see gitops.md)
make argocd-apply

# Secrets still required out-of-band
kubectl -n juiceshop-chatbot create secret generic juiceshop-chatbot-secrets \
  --from-literal=OPEN_AI_KEY="$OPEN_AI_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# For local images, either:
#  A) keep using make deploy (imperative), or
#  B) push to GHCR and let Argo sync overlays/dev|prod
```

## 4) CI-driven deploy

1. Push to `develop` or `main`.
2. **Platform CI/CD** builds, scans, signs, pushes GHCR.
3. GitOps commit updates overlay tags.
4. ArgoCD syncs `juiceshop-chatbot-dev` / `juiceshop-chatbot-prod`.

## Image matrix

| Image | Dockerfile |
|-------|------------|
| `owasp-juiceshop-chatbot-frontend` | `./Dockerfile` |
| `owasp-juiceshop-chatbot-backend` | `backend/Dockerfile` |
| `owasp-juiceshop-chatbot-chromadb` | `chromadb/Dockerfile` |
| `owasp-juiceshop-chatbot-gateway` | `deploy/Dockerfile.gateway` (Compose/CI; not in Kustomize base) |

## Prerequisites

- Docker / Colima
- `kubectl`, `kind`, `helm` (optional)
- Node 24+ / Python 3.11+ for local tests
- OpenAI API key for chat features

## Rollback

**GitOps:** revert the GitOps tag commit or pin `newTag` in the overlay; ArgoCD self-heals.

**Imperative KIND:**

```bash
kubectl -n juiceshop-chatbot rollout undo deployment/juiceshop-chatbot-backend
kubectl -n juiceshop-chatbot rollout undo deployment/juiceshop-chatbot-frontend
```

## Related

- [GitOps](gitops.md) · [CI/CD](cicd.md) · [DevSecOps](devsecops.md) · [Monitoring](monitoring.md) · [Troubleshooting](troubleshooting.md)
