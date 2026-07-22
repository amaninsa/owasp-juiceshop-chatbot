# Screenshots for LinkedIn & portfolio

Capture these in order after a healthy `make demo` session. Store files under `docs/screenshots/` (create locally; large binaries may stay untracked).

Export architecture PNGs from [mermaid.live](https://mermaid.live) using [`diagrams/*.mmd`](./diagrams/).

---

## Recommended order

| # | Shot | How to capture | Caption idea |
|---|------|----------------|--------------|
| 1 | **AI Chat** | http://juiceshop-chatbot.local:8080 — ask a product question | “RAG chatbot on Kubernetes — grounded answers from ChromaDB + OpenAI” |
| 2 | **Kubernetes Pods** | `kubectl get pods -A` or Lens/k9s | “App, monitoring, Argo CD, and ingress namespaces — all Ready” |
| 3 | **Architecture** | PNG from `docs/diagrams/platform-overview.mmd` | “CI/CD → GHCR → Argo CD → Kubernetes → Observability” |
| 4 | **Prometheus Targets** | Prometheus → Status → Targets | “Scraping FastAPI `/metrics` with NetworkPolicy-aware discovery” |
| 5 | **Grafana Dashboard** | Cluster Overview or AI Assistant dashboard | “ConfigMap-provisioned dashboards — no click-ops” |
| 6 | **Loki Logs** | Grafana Explore → Loki | “Promtail → Loki → Explore for app + ingress logs” |
| 7 | **Argo CD** | App of Apps + Tree / Sync Healthy | “GitOps with auto-sync, prune, and self-heal” |
| 8 | **GitHub Actions** | Actions → Platform CI/CD green run | “DevSecOps: Gitleaks, Trivy, Cosign, GHCR, GitOps tags” |

---

## Tips

- Use a clean browser profile; hide personal bookmarks.
- Prefer 1920×1080; crop tightly around the subject.
- Dark Grafana theme photographs well; keep Prometheus default for clarity.
- Blur or omit any real API keys / secrets in terminal panes.
- Pair the carousel with a short LinkedIn post linking the GitHub repo.

---

## LinkedIn post skeleton

> Built a Cloud Native AI platform on Kubernetes (KIND): RAG chatbot (FastAPI + ChromaDB + OpenAI), GitOps with Argo CD, GitHub Actions → GHCR with Cosign, and observability with Prometheus / Grafana / Loki.  
> Optimized for local Apple Silicon demos, production-inspired overlays for real clusters.  
> Repo: https://github.com/amaninsa/owasp-juiceshop-chatbot
