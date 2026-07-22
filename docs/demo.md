# Demo guide (≈ 10 minutes)

A structured walkthrough for interviews, LinkedIn recordings, and technical demos.
Companion script: [`demo-script.md`](./demo-script.md). Commands: `make demo` · `make urls`.

---

## Before you start (2 min)

```bash
make doctor
make kind-up          # if needed
make deploy
make monitoring
make argocd-install && make argocd-apply
make urls
```

Add hosts entries printed by `make urls`.

---

## Minute-by-minute

### 1. Open the GitHub repository (30s)

URL: https://github.com/amaninsa/owasp-juiceshop-chatbot

Show:

- README badges (CI, Kubernetes, Prometheus, Grafana, Argo CD, …)
- Folder map: `backend/`, `apps/`, `k8s/monitoring/`, `argocd/`, `.github/workflows/`
- Docs hub: [`docs/README.md`](./README.md)

**Talking point:** “This is a production-inspired Cloud Native AI platform I run locally on KIND for demos.”

---

### 2. Explain the repository (1 min)

| Area | What to say |
|------|-------------|
| App | Angular Juice Shop + FastAPI RAG + ChromaDB + OpenAI |
| Delivery | Docker → GHCR → Argo CD → Kubernetes |
| Ops | Prometheus / Grafana / Loki / Alertmanager |
| Security | Gitleaks, Trivy, Cosign, NetworkPolicies |

Open [`architecture.md`](./architecture.md) diagram briefly.

---

### 3. Deploy / show Kubernetes (1 min)

```bash
make demo
# or:
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
```

Highlight namespaces: `juiceshop-chatbot`, `monitoring`, `argocd`, `ingress-nginx`.

---

### 4. Frontend + AI question (1.5 min)

Open: http://juiceshop-chatbot.local:8080

1. Open the AI chat widget.
2. Ask: *“What is the price of the Apple Juice?”*
3. Show a grounded product answer.

**Explain RAG:** embed query → Chroma similarity search → GPT completion with retrieved context (not hallucinated catalog).

Optional API:

```bash
curl -s -X POST http://juiceshop-chatbot.local:8080/ai-assistant/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"What is the price of the Apple Juice?"}'
```

---

### 5. Prometheus (1.5 min)

Open: http://prometheus.juiceshop-chatbot.local:8080

1. **Status → Targets** — backend scrape UP.
2. Run PromQL:

```promql
up{job="juiceshop-chatbot-backend"}
rate(http_requests_total[5m])
```

(Adjust metric names to match your `/metrics` output if needed.)

**Explain:** scrape → TSDB (24h / 512MB local) → rules → Alertmanager.

---

### 6. Grafana dashboards (1.5 min)

Open: http://grafana.juiceshop-chatbot.local:8080 (`admin` / `admin`)

Show:

- Kubernetes Cluster Overview
- Backend / AI Assistant dashboards
- Datasources: Prometheus + Loki (provisioned from ConfigMaps)

---

### 7. Loki logs (1 min)

Grafana → **Explore** → Loki → query app namespace logs, e.g.:

```logql
{namespace="juiceshop-chatbot"} |= "chat"
```

**Explain:** Promtail → Loki (filesystem, 24h retention, compactor) → Grafana.

---

### 8. Alertmanager (30s)

Open: http://alertmanager.juiceshop-chatbot.local:8080

Show groups / silences. Mention alert rules in `k8s/monitoring/base/alerts/`.

---

### 9. Argo CD (1.5 min)

Open: http://argocd.juiceshop-chatbot.local:8080 (`admin` / `make argocd-password`)

Show:

- App of Apps root
- Child apps (local / monitoring)
- Sync status, Health, Tree view
- Auto-sync, prune, self-heal

---

### 10. GitHub Actions + close (1 min)

Open: https://github.com/amaninsa/owasp-juiceshop-chatbot/actions

Walk: lint → test → build → scan → sign → GHCR → GitOps tag → Argo sync.

**Close:** “Same patterns you’d use toward EKS/GKE — optimized here for KIND on Apple Silicon.”

---

## Cheat sheet

| What | Command / URL |
|------|----------------|
| Health | `make doctor` |
| Demo dump | `make demo` |
| URLs | `make urls` |
| AI | http://juiceshop-chatbot.local:8080 |
| Grafana | http://grafana.juiceshop-chatbot.local:8080 |
| Prometheus | http://prometheus.juiceshop-chatbot.local:8080 |
| Alertmanager | http://alertmanager.juiceshop-chatbot.local:8080 |
| Argo CD | http://argocd.juiceshop-chatbot.local:8080 |
