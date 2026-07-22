# Architecture — Juice Shop AI Cloud Native Platform

Production-inspired platform architecture for a RAG chatbot on Kubernetes.
Diagrams are Mermaid (GitHub-native). Export PNG from [mermaid.live](https://mermaid.live) or the sources under [`docs/diagrams/`](./diagrams/).

---

## 1. End-to-end platform (CI → GitOps → runtime → observability)

```mermaid
flowchart TB
  DEV[Developer] --> GH[GitHub Repository]
  GH --> GHA[GitHub Actions<br/>Platform CI/CD]
  GHA --> BUILD[Docker Build<br/>+ Trivy / Syft / Cosign]
  BUILD --> GHCR[GitHub Container Registry]
  GHCR --> ARGO[Argo CD<br/>App of Apps]
  ARGO --> K8S[Kubernetes / KIND]

  subgraph Runtime["Namespace: juiceshop-chatbot"]
    FE[Frontend<br/>Angular Juice Shop]
    BE[Backend<br/>FastAPI RAG]
    CH[(ChromaDB)]
  end

  K8S --> FE
  K8S --> BE
  K8S --> CH
  BE --> CH
  BE --> OAI[OpenAI API]

  subgraph Obs["Namespace: monitoring"]
    PROM[Prometheus]
    GRAF[Grafana]
    LOKI[Loki]
    AM[Alertmanager]
  end

  BE -->|/metrics| PROM
  PROM --> GRAF
  PROM --> AM
  LOKI --> GRAF
```

Source: [`diagrams/platform-overview.mmd`](./diagrams/platform-overview.mmd)

---

## 2. Request path (user → AI)

```mermaid
flowchart LR
  U[Browser + AI Widget] --> ING[ingress-nginx :8080]
  ING -->|"/"| FE[Frontend]
  ING -->|"/ai-assistant/*"| BE[FastAPI]
  BE --> CH[(ChromaDB)]
  BE --> OAI[OpenAI]
```

---

## 3. Kubernetes layout

```mermaid
flowchart TB
  subgraph Cluster["KIND cluster: juiceshop-chatbot"]
    subgraph IngressNS["ingress-nginx"]
      IC[Ingress Controller]
    end
    subgraph AppNS["juiceshop-chatbot"]
      FE[frontend]
      BE[backend]
      CH[chromadb]
    end
    subgraph MonNS["monitoring"]
      P[prometheus]
      G[grafana]
      L[loki]
      A[alertmanager]
    end
    subgraph ArgoNS["argocd"]
      AS[argocd-server]
      RS[repo-server]
    end
  end
  IC --> AppNS
  IC --> MonNS
  IC --> ArgoNS
```

---

## 4. GitHub Actions → GHCR → Argo CD

```mermaid
flowchart LR
  PR[PR / push] --> SEC[DevSecOps gates]
  SEC --> QT[Lint + Tests]
  QT --> KQ[kubeconform]
  KQ --> IMG[Build images]
  IMG --> SCAN[Trivy + Syft + Cosign]
  SCAN --> REG[Push GHCR]
  REG --> TAG[GitOps tag commit]
  TAG --> SYNC[Argo CD auto-sync]
  SYNC --> ROLL[Kubernetes rollout]
```

Details: [`github-actions.md`](./github-actions.md) · [`cicd.md`](./cicd.md)

---

## 5. GitOps (App of Apps)

```mermaid
sequenceDiagram
  participant Dev as Developer
  participant GH as GitHub
  participant CI as Platform CI
  participant Root as Argo CD Root
  participant App as Child Application
  participant K8s as Cluster

  Dev->>GH: Merge
  GH->>CI: platform-ci.yml
  CI->>REG: Push signed images
  CI->>GH: Update overlay image tags
  Root->>GH: Watch argocd/apps
  Root->>App: Ensure Application CR
  App->>GH: Detect desired state
  App->>K8s: Sync (prune + selfHeal)
```

Details: [`argocd.md`](./argocd.md) · [`gitops.md`](./gitops.md)

---

## 6. RAG sequence

```mermaid
sequenceDiagram
  participant U as User
  participant API as FastAPI
  participant C as ChromaDB
  participant O as OpenAI
  U->>API: POST /chat
  API->>O: Embed query
  API->>C: Similarity search
  C-->>API: Product context
  API->>O: Chat completion
  O-->>API: Grounded reply
  API-->>U: Answer + correlation_id
```

---

## 7. Observability data flow

```mermaid
flowchart LR
  BE[Backend /metrics] --> PROM[Prometheus]
  KSM[kube-state-metrics] --> PROM
  NE[node-exporter] --> PROM
  PT[Promtail] --> LOKI[Loki]
  PROM --> GRAF[Grafana]
  LOKI --> GRAF
  PROM --> AM[Alertmanager]
```

Local profile notes: emptyDir + 24h retention; **cAdvisor DaemonSet disabled** (see [`monitoring.md`](./monitoring.md)).

---

## Overlays / namespaces

| Path | Namespace | Audience |
|------|-----------|----------|
| `apps/overlays/local` | `juiceshop-chatbot` | KIND laptop |
| `apps/overlays/dev` | `juiceshop-chatbot-dev` | Shared / staging |
| `apps/overlays/prod` | `juiceshop-chatbot-prod` | Production-style |
| `k8s/monitoring/local` | `monitoring` | KIND observability |
| `k8s/monitoring/production` | `monitoring` | PVC + longer retention |

---

## Export PNG

1. Open [`diagrams/platform-overview.mmd`](./diagrams/platform-overview.mmd) in [mermaid.live](https://mermaid.live).
2. **Actions → PNG / SVG**.
3. Save under `docs/screenshots/` for LinkedIn (see [`screenshots.md`](./screenshots.md)).
