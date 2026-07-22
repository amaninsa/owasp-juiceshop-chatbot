# Demo presentation script

Spoken narration for a live or recorded demo (~8–12 minutes).  
Commands assume KIND is already up (`make kind-up && make deploy && make monitoring`).

---

## Opening

> “Today I’ll demonstrate an **AI-powered Cloud Native platform** running locally on Kubernetes with KIND.  
> It combines a RAG chatbot — Angular frontend, FastAPI backend, ChromaDB, and OpenAI — with the platform layer recruiters expect: GitOps with Argo CD, CI/CD with GitHub Actions, and full observability with Prometheus, Grafana, Loki, and Alertmanager.  
> It’s optimized for Apple Silicon demos, but the patterns map cleanly to production clusters.”

Show GitHub README badges and folder structure.

---

## 1. Architecture (1 min)

> “Traffic enters through ingress-nginx. The Juice Shop UI is served from the frontend Deployment. Chat requests go to the FastAPI backend under `/ai-assistant`. The backend embeds the question, retrieves relevant products from ChromaDB, and asks OpenAI for a grounded answer.”

Open [`architecture.md`](./architecture.md) or the Mermaid diagram in the README.

```bash
make urls
```

---

## 2. Cluster health (1 min)

> “First, the control plane. Single-node KIND — intentional for local demos, not HA.”

```bash
make doctor
make demo
```

> “You can see the app namespace, monitoring, Argo CD, and ingress. Pods are Ready. That green health is the bar I hold before any interview demo.”

---

## 3. Application + RAG (2 min)

Open http://juiceshop-chatbot.local:8080

> “Here’s the shopping UI with an embedded AI assistant. I’ll ask about a real catalog product.”

Ask: *“What is the price of the Apple Juice?”*

> “This is Retrieval-Augmented Generation. We don’t fine-tune a model on the catalog. We retrieve product chunks from Chroma, then generate. That keeps answers tied to inventory and prices. Correlation IDs in the response help with tracing in logs.”

Optional:

```bash
curl -s -X POST http://juiceshop-chatbot.local:8080/ai-assistant/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"What is the price of the Apple Juice?"}' | jq .
```

---

## 4. Metrics — Prometheus (1.5 min)

Open http://prometheus.juiceshop-chatbot.local:8080 → **Status → Targets**

> “Prometheus scrapes the backend `/metrics` endpoint, plus kube-state-metrics and node-exporter. On the local profile we keep 24-hour retention and a 512MB TSDB cap, on emptyDir, so KIND disk doesn’t fill up.”

Run:

```promql
up
```

> “Green targets mean the scrape path and NetworkPolicy allow Prometheus to reach the backend.”

---

## 5. Dashboards — Grafana (1.5 min)

Open http://grafana.juiceshop-chatbot.local:8080

> “Dashboards and datasources are provisioned from ConfigMaps — no click-ops. I’ll open the cluster overview and the AI assistant dashboard. That shows HTTP and chat-oriented metrics from the FastAPI instrumentation.”

---

## 6. Logs — Loki (1 min)

Grafana → Explore → Loki

```logql
{namespace="juiceshop-chatbot"}
```

> “Promtail ships container logs into Loki. Retention is 24 hours locally with the compactor cleaning old chunks. Same Explore UX you’d use with a central logging stack.”

---

## 7. Alerting — Alertmanager (30s)

Open http://alertmanager.juiceshop-chatbot.local:8080

> “Alert rules live with the monitoring manifests. Alertmanager receives firing alerts from Prometheus — in production you’d route to Slack or PagerDuty; locally we keep the UI for demos.”

---

## 8. GitOps — Argo CD (2 min)

Open http://argocd.juiceshop-chatbot.local:8080

> “Desired state is Git. The root Application syncs child apps — App of Apps. Auto-sync, prune, and self-heal mean cluster drift is corrected automatically. Tree view shows every Kubernetes object Argo manages. History and rollback are one click if a bad sync lands.”

```bash
kubectl -n argocd get applications
make argocd-status
```

---

## 9. CI/CD + DevSecOps (1.5 min)

Open GitHub Actions → **Platform CI/CD**

> “Every push runs secret scanning, SAST, dependency audits, lint, tests, Kubernetes validation, image build, Trivy, SBOM with Syft, Cosign signing, push to GHCR, then a GitOps tag commit. Argo picks up the new digests and rolls the cluster. That’s the path from commit to running pods.”

---

## Closing

> “To summarize: AI application on Kubernetes, delivered with GitOps and a hardened pipeline, observed with metrics, logs, and alerts — all runnable on a laptop with KIND.  
> Happy to go deeper on RAG, NetworkPolicies, or how the local vs production monitoring overlays differ.”

---

## Backup commands

```bash
make status
make monitoring-status
make argocd-status
make logs-backend
make validate
```
