# KIND local deployment

## Prerequisites

- Docker (Colima / Docker Desktop)
- [kind](https://kind.sigs.k8s.io/) (`brew install kind`)
- kubectl
- make
- `.env.openai` with `OPEN_AI_KEY=...`

## Quick start

```bash
# 1) Create cluster + ingress-nginx
make kind-up

# 2) Build images, load into KIND, apply manifests
make deploy

# 3a) Access via ingress (add hosts entry once)
#     127.0.0.1 juiceshop-chatbot.local
open http://juiceshop-chatbot.local:8080

# 3b) Or port-forward without /etc/hosts
make port-forward
# Frontend: http://127.0.0.1:3000
# Backend:  http://127.0.0.1:8000
```

## Make targets

| Target | Description |
|--------|-------------|
| `make kind-up` | Create KIND cluster + install ingress-nginx |
| `make deploy` | Build/load images and apply `k8s/` |
| `make deploy-fast` | Apply without rebuilding images |
| `make status` | Pods / services / ingress / events |
| `make logs` | Tail all app logs |
| `make port-forward` | Forward frontend `:3000` and backend `:8000` |
| `make delete` | Delete workloads (keep cluster) |
| `make delete-all` | Delete workloads + destroy cluster |

## Notes

- Ingress HTTP is mapped to host port **8080** (see `kind-config.yaml`).
- Chroma data is persisted under `data/kind/chromadb` via KIND `extraMounts`.
- Images used: `owasp-juiceshop-chatbot-chromadb:local`, `owasp-juiceshop-chatbot-backend:local`, `owasp-juiceshop-chatbot-frontend:local`.
- First `make deploy` builds the Juice Shop image and can take several minutes.
