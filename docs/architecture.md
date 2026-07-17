# Architecture diagrams

Mermaid diagrams for the Juice Shop AI platform. Rendered in GitHub, most IDEs, and [mermaid.live](https://mermaid.live).

Also summarized in [`AI-PLATFORM.md`](../AI-PLATFORM.md).

---

## 1. Overall architecture

End-to-end request and data flow across client, edge, workloads, and OpenAI.

```mermaid
flowchart TB
  subgraph Users
    B[Browser / AI Chat Widget]
  end

  subgraph Edge["Edge"]
    I[Ingress / nginx Gateway]
  end

  subgraph Platform["juiceshop-chatbot namespace"]
    FE[Frontend<br/>OWASP Juice Shop]
    BE[Backend<br/>FastAPI RAG]
    CH[(ChromaDB<br/>product embeddings)]
  end

  subgraph External["External"]
    OAI[OpenAI<br/>embeddings + chat]
  end

  B -->|"HTTP"| I
  I -->|"/ "| FE
  I -->|"/ai-assistant/*"| BE
  B -.->|"same-origin chat"| I
  BE -->|"retrieve top-K"| CH
  BE -->|"embed + complete"| OAI
  BE -.->|"ingest products"| CH
```

---

## 2. Kubernetes architecture

Workloads, storage, config, and traffic inside the cluster (KIND / cloud).

```mermaid
flowchart TB
  subgraph Cluster["Kubernetes cluster"]
    subgraph IngressNS["ingress-nginx"]
      IC[Ingress Controller]
    end

    subgraph NS["namespace: juiceshop-chatbot"]
      ING[Ingress rules<br/>juiceshop-chatbot.local]
      SVC_FE[Service frontend :3000]
      SVC_BE[Service backend :8000]
      SVC_CH[Service chromadb :8000]

      DEP_FE[Deployment frontend]
      DEP_BE[Deployment backend]
      DEP_CH[Deployment chromadb]

      CM[ConfigMap<br/>juiceshop-chatbot-config]
      SEC[Secret<br/>juiceshop-chatbot-secrets]
      PVC[PVC + PV<br/>Chroma data]
      NP[NetworkPolicies]
      SA[ServiceAccounts + RBAC]
    end
  end

  IC --> ING
  ING --> SVC_FE --> DEP_FE
  ING --> SVC_BE --> DEP_BE
  DEP_BE --> SVC_CH --> DEP_CH
  DEP_CH --> PVC
  DEP_BE --> CM
  DEP_BE --> SEC
  DEP_FE --> CM
  NP -.-> DEP_FE & DEP_BE & DEP_CH
  SA -.-> DEP_FE & DEP_BE & DEP_CH
```

---

## 3. GitHub Actions flow

CI/CD pipeline for the AI platform (`.github/workflows/ai-platform-ci.yml`).

```mermaid
flowchart LR
  subgraph Trigger
    T1[push develop/main]
    T2[pull_request]
    T3[workflow_dispatch]
  end

  subgraph Quality
    Q1[Ruff lint/format]
    Q2[Pytest]
    Q3[ESLint widget]
    Q4[Helm + Kustomize]
  end

  subgraph Supply
    B[Build images]
    S[Trivy scan]
    P[Push GHCR<br/>latest / sha / semver]
  end

  subgraph Deploy
    K[KIND smoke<br/>apps/overlays/ci]
    G[Commit GitOps tags<br/>ArgoCD path]
  end

  T1 & T2 & T3 --> Q1 & Q2 & Q3 & Q4
  Q1 & Q2 & Q3 & Q4 --> B
  B --> S --> P
  P --> K
  P --> G
```

---

## 4. GitOps flow

Desired state in Git; ArgoCD reconciles the cluster.

```mermaid
sequenceDiagram
  participant Dev as Developer
  participant GH as GitHub
  participant CI as GitHub Actions
  participant Argo as ArgoCD
  participant K8s as Cluster

  Dev->>GH: Merge to develop/main
  GH->>CI: ai-platform-ci.yml
  CI->>CI: Build / scan / push GHCR
  CI->>GH: Commit image tags<br/>apps/overlays/dev|prod
  Argo->>GH: Detect drift (poll/webhook)
  Argo->>K8s: Sync Application<br/>prune + selfHeal
  K8s->>K8s: Rollout new pods
  Note over Argo,K8s: Manual drift is reverted by selfHeal
```

**Overlays**

| Path | Audience |
|------|----------|
| `apps/overlays/local` | KIND laptop |
| `apps/overlays/dev` | Shared/dev cluster |
| `apps/overlays/prod` | Production |
| `apps/overlays/ci` | Ephemeral CI KIND |

---

## 5. RAG flow

Product Q&A: retrieve relevant Juice Shop products, then generate an answer.

```mermaid
sequenceDiagram
  participant U as User
  participant W as Chat Widget
  participant API as FastAPI /chat
  participant R as ProductRetriever
  participant C as ChromaDB
  participant O as OpenAI

  U->>W: Ask about a product / price
  W->>API: POST /chat {message, history}
  API->>R: retrieve(query)
  R->>O: embed query
  O-->>R: query vector
  R->>C: similarity search top-K
  C-->>R: product documents + metadata
  R-->>API: formatted context
  API->>O: chat completion<br/>system + context + history
  O-->>API: reply
  API-->>W: {reply, correlation_id}
  W-->>U: Render answer

  Note over API,C: Startup / POST /ingest embeds<br/>config/default.yml products into Chroma
```

**Ingest (offline / startup)**

```mermaid
flowchart LR
  Y[config/default.yml] --> P[products.py]
  P --> E[OpenAI embeddings]
  E --> U[Upsert Chroma collection<br/>juice_shop_products]
```

---

## How to edit

1. Change the Mermaid source in this file.
2. Preview on GitHub or paste into [mermaid.live](https://mermaid.live).
3. Keep diagrams aligned with `apps/base`, `backend/`, and `AI-PLATFORM.md`.
