# Repository structure (AI platform)

Target layout after Task 7:

```text
owasp-juiceshop-chatbot/
├── frontend/                 # Angular Juice Shop UI (+ AI chat widget)
├── backend/                  # FastAPI RAG assistant (was ai-assistant/)
├── chromadb/                 # ChromaDB image + config
├── deploy/                   # nginx gateway Dockerfile + conf
├── apps/                     # GitOps Kustomize base + overlays
├── helm/                     # Helm chart
├── k8s/                      # Thin wrapper → apps/overlays/local
├── argocd/                   # ArgoCD Project + Applications
├── .github/workflows/        # CI/CD (ai-platform-ci.yml, …)
├── scripts/                  # KIND/deploy/GitOps helpers
├── docs/                     # Platform docs
├── Makefile
├── docker-compose.yml
├── kind-config.yaml
├── kind-config.ci.yaml
└── README.md
```

## Compatibility

| Concern | Choice |
|---------|--------|
| Folder | Canonical code lives in `backend/` |
| Symlink | `ai-assistant` → `backend` (old paths still resolve) |
| Compose service | `backend` (nginx proxies to `backend:8000`) |
| HTTP path | Still `/ai-assistant/*` (unchanged for the widget) |
| Container image | Still `owasp-juiceshop-chatbot-backend` (registry/K8s continuity) |
| K8s Deployment | Still `juiceshop-chatbot-backend` |

## Quick map

| Path | Role |
|------|------|
| `backend/` | Python FastAPI + RAG + ingest |
| `frontend/` | Angular app |
| `chromadb/` | Vector DB image |
| `apps/` | GitOps manifests |
| `helm/` | Packaged install |
| `deploy/` | Same-origin gateway |
