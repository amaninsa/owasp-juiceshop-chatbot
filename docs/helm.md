# Helm packaging / install for Juice Shop AI

## Install (KIND / local)

```bash
make kind-up
make build-images && make load-images

# Secret must exist when using values-local.yaml
kubectl -n juiceshop-chatbot create secret generic juiceshop-chatbot-secrets \
  --from-literal=OPEN_AI_KEY="sk-..." \
  --dry-run=client -o yaml | kubectl apply -f -

make helm-install
# equivalent:
# helm upgrade --install juiceshop-chatbot ./helm \
#   -n juiceshop-chatbot --create-namespace \
#   -f ./helm/values-local.yaml --wait
```

## Value files

| File | Purpose |
|------|---------|
| `values.yaml` | Defaults / production-oriented |
| `values-dev.yaml` | Smaller replicas/resources |
| `values-local.yaml` | KIND local images + hostPath PV |

## Common overrides

```bash
helm upgrade --install juiceshop-chatbot ./helm -n juiceshop-chatbot \
  -f ./helm/values-local.yaml \
  --set backend.replicaCount=2 \
  --set backend.image.tag=abc123 \
  --set backend.openai.apiKey=sk-... \
  --set chromadb.persistence.size=10Gi \
  --set ingress.host=juiceshop-chatbot.example.com
```

## Lint / render

```bash
make helm-lint
make helm-template
```

Note: prefer either raw `k8s/` manifests (`make deploy`) **or** Helm (`make helm-install`) in a given namespace to avoid name conflicts.
