# Repository structure (AI platform)

```text
owasp-juiceshop-chatbot/
├── frontend/                 # Angular Juice Shop UI (+ AI chat widget)
├── backend/                  # FastAPI RAG assistant
├── chromadb/                 # ChromaDB image + config
├── deploy/                   # nginx gateway Dockerfile + conf
├── apps/                     # GitOps Kustomize base + overlays
├── helm/                     # Helm chart
├── k8s/                      # Manifests + monitoring overlays
│   └── monitoring/           # base / local / production
├── argocd/                   # App of Apps + local KIND patches
├── .github/workflows/        # platform-ci.yml (+ supporting)
├── scripts/                  # doctor, demo, urls, kind-up, deploy, …
├── docs/                     # Portfolio docs + diagrams/
├── Makefile
├── docker-compose.yml
├── kind-config.yaml
└── README.md
```

Docs index: [README.md](./README.md)

## Compatibility

| Concern | Choice |
|---------|--------|
| Folder | Canonical code lives in `backend/` |
| Symlink | `ai-assistant` → `backend` |
| Monitoring docs | Use `docs/monitoring.md` |
| CI docs | Use `docs/github-actions.md` + `docs/cicd.md` |
