# Validation

Script: [`scripts/validate.sh`](../scripts/validate.sh)

Checks a running Juice Shop AI deployment (KIND / any kube context).

## What it validates

| Area | Check |
|------|--------|
| Namespace | `juiceshop-chatbot` exists |
| Deployments | frontend, backend, chromadb ready |
| Pods | all Running |
| Services | frontend, backend, chromadb |
| Ingress | at least one Ingress |
| PVC | `juiceshop-chatbot-chromadb-pvc` Bound |
| Backend health | `/livez`, `/readyz`, `/health`, `/metrics` |
| Vector DB | Chroma `/api/v1/heartbeat` |
| Frontend | HTTP `/` |
| OpenAI | `GET https://api.openai.com/v1/models` with cluster/local key |

## Usage

```bash
# After make kind-up && make deploy
make validate

# Skip live OpenAI call
SKIP_OPENAI=true make validate

# Also hit Ingress URLs
FRONTEND_URL=http://juiceshop-chatbot.local:8080 \
BACKEND_URL=http://juiceshop-chatbot.local:8080/ai-assistant \
  make validate
```

## Environment

| Variable | Default | Meaning |
|----------|---------|---------|
| `CLUSTER_NAME` | `juiceshop-chatbot` | KIND cluster name |
| `CONTEXT` | `kind-${CLUSTER_NAME}` | kubectl context |
| `NAMESPACE` | `juiceshop-chatbot` | app namespace |
| `SKIP_OPENAI` | `false` | skip external API check |
| `FRONTEND_URL` | _(empty)_ | optional Ingress frontend base |
| `BACKEND_URL` | _(empty)_ | optional Ingress AI base |
| `TIMEOUT_SECONDS` | `120` | deployment wait timeout |

Exit code `0` = all required checks passed; `1` = one or more failures; `2` = prerequisite error.
