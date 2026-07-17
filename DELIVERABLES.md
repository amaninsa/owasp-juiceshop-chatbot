# Deliverables — Juice Shop AI Platform

**Status: Tasks 1–13 complete**

Cloud-native RAG assistant stacked on OWASP Juice Shop (FastAPI + ChromaDB + OpenAI + Angular widget + Compose/KIND/Helm/GitOps/CI).

| Start here | |
|------------|--|
| Platform README | [`AI-PLATFORM.md`](./AI-PLATFORM.md) |
| Architecture diagrams | [`docs/architecture.md`](./docs/architecture.md) |
| Upstream Juice Shop | [`README.md`](./README.md) |

---

## Task checklist

| # | Task | Status | Key artifacts |
|---|------|--------|----------------|
| 1 | Containerization | Done | `backend/Dockerfile`, `chromadb/Dockerfile`, `deploy/Dockerfile.gateway`, `docker-compose.yml` |
| 2 | Kubernetes manifests | Done | `apps/base/**` |
| 3 | KIND + Makefile | Done | `kind-config.yaml`, `scripts/*`, `Makefile` |
| 4 | Helm | Done | `helm/` |
| 5 | GitOps | Done | `apps/overlays/*`, `argocd/`, `k8s/` wrapper |
| 6 | CI/CD | Done | `.github/workflows/ai-platform-ci.yml` |
| 7 | Repo structure | Done | `frontend/`, `backend/`, `chromadb/`, … |
| 8 | Observability | Done | `/livez` `/readyz` `/health` `/metrics`, logs, Grafana |
| 9 | Security | Done | Secrets OOB, RBAC, NetworkPolicy, hardened SecurityContext |
| 10 | Documentation | Done | `AI-PLATFORM.md` |
| 11 | Architecture diagrams | Done | `docs/architecture.md` |
| 12 | Validation | Done | `scripts/validate.sh`, `make validate` |
| 13 | Deliverables wrap-up | Done | **This file** |

---

## Platform layout (deliverable tree)

```text
frontend/              Angular Juice Shop + AI widget
backend/               FastAPI RAG (symlink: ai-assistant → backend)
chromadb/              Vector DB image
deploy/                nginx gateway (Compose)
apps/                  GitOps Kustomize base + overlays (local/dev/prod/ci)
helm/                  Helm chart + values
k8s/                   Compatibility wrapper → apps/overlays/local
argocd/                ArgoCD Project + Applications
.github/workflows/     ai-platform-ci.yml (+ upstream Juice Shop workflows)
scripts/               kind-up, deploy, validate, …
docs/                  Platform runbooks + architecture
monitoring/            Grafana AI dashboard JSON
Makefile               Local orchestration
docker-compose.yml     Local multi-service stack
kind-config.yaml       Local KIND (hostPath)
kind-config.ci.yaml    CI KIND
AI-PLATFORM.md         Platform README
DELIVERABLES.md        This checklist
```

---

## Acceptance map

| Requirement | Location |
|-------------|----------|
| Dockerized FE / BE / Chroma / gateway | `docker-compose.yml` |
| Production Dockerfiles + healthchecks | `backend/`, `chromadb/`, root `Dockerfile`, `deploy/` |
| K8s Deployments / Services / Ingress / PVC | `apps/base/` |
| KIND | `make kind-up` · `make deploy` |
| Helm | `helm/` · `make helm-install` |
| ArgoCD + Kustomize overlays | `argocd/` · `apps/overlays/` |
| GitHub Actions (lint/test/build/scan/push) | `ai-platform-ci.yml` |
| Prometheus + Grafana | `/metrics` · `monitoring/grafana-ai-assistant-dashboard.json` |
| Secrets / SC / NetworkPolicy / RBAC | `docs/security.md` · `apps/base/rbac` · `apps/base/networkpolicy` |
| Validation | `make validate` |

---

## Command cheat sheet

```bash
# Secrets
echo 'OPEN_AI_KEY=sk-...' > .env.openai

# Docker Compose
docker compose up --build
# → http://localhost:3000

# KIND
make kind-up
make deploy
make validate
# /etc/hosts: 127.0.0.1 juiceshop-chatbot.local
# → http://juiceshop-chatbot.local:8080

# Helm (do not mix with Kustomize in same ns)
make build-images && make load-images
make helm-install

# Local backend quality
make ci-lint && make ci-test

# GitOps render
make kustomize-local
kubectl apply -k argocd/   # after editing repoURL
```

---

## Compatibility (intentionally unchanged)

| Concern | Choice |
|---------|--------|
| HTTP path | `/ai-assistant/*` |
| Image name | `owasp-juiceshop-chatbot-backend` |
| Symlink | `ai-assistant` → `backend` |
| Upstream Juice Shop challenges / core app | Untouched except AI widget integration already in place |
| Secrets in Git | Never — create `juiceshop-chatbot-secrets` out-of-band |

---

## Design principles

- Step-by-step delivery with confirmation between tasks  
- Reuse existing RAG + widget implementation  
- Backward-compatible URLs and image names  
- GitOps-friendly overlays; no plaintext keys in repo  
- Production practices: probes, resources, non-root, NetworkPolicy, RBAC, image scan  

---

## Documentation index

| Doc | Purpose |
|-----|---------|
| [AI-PLATFORM.md](./AI-PLATFORM.md) | Platform README |
| [docs/architecture.md](./docs/architecture.md) | Mermaid diagrams |
| [docs/kind-deployment.md](./docs/kind-deployment.md) | KIND |
| [docs/helm.md](./docs/helm.md) | Helm |
| [docs/gitops.md](./docs/gitops.md) | ArgoCD |
| [docs/ci-cd.md](./docs/ci-cd.md) | GitHub Actions |
| [docs/observability.md](./docs/observability.md) | Metrics / logs |
| [docs/security.md](./docs/security.md) | Hardening |
| [docs/validation.md](./docs/validation.md) | Validation script |
| [docs/repository-structure.md](./docs/repository-structure.md) | Layout |

---

## Optional follow-ups (non-blocking)

External Secrets · HPA/PDB · OpenTelemetry · multi-arch images · Argo Rollouts · Cypress chat e2e · local LLM path — see **Future improvements** in `AI-PLATFORM.md`.

---

**Task 13 complete.** All planned platform deliverables are in-repo and documented.
