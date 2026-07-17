# Security hardening

## Secrets

OpenAI keys are **never** committed.

```bash
kubectl -n juiceshop-chatbot create secret generic juiceshop-chatbot-secrets \
  --from-literal=OPEN_AI_KEY="sk-..." \
  --dry-run=client -o yaml | kubectl apply -f -
```

- GitOps base does **not** include a Secret resource
- Example only: `k8s/config/secret.example.yaml`
- Helm: prefer `backend.openai.existingSecret` (see `values-local.yaml`)

## Pod security

| Workload | runAsNonRoot | drop ALL | readOnlyRootFilesystem | ServiceAccount |
|----------|--------------|----------|------------------------|----------------|
| Backend | UID 10001 | yes | yes (+ `/tmp` emptyDir) | `juiceshop-chatbot-backend` |
| Frontend | UID 65532 | yes | yes (+ `/tmp` emptyDir) | `juiceshop-chatbot-frontend` |
| ChromaDB | UID 1000 | yes | false (PVC data dir) | `juiceshop-chatbot-chromadb` |
| Init (wait) | UID 100 | yes | yes | (pod SA) |

All pods: `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, `automountServiceAccountToken: false`.

## RBAC

- Dedicated ServiceAccounts (no default SA)
- Backend Role/RoleBinding: `get` on `juiceshop-chatbot-config` + `juiceshop-chatbot-secrets` only
- Frontend / ChromaDB: no API RoleBinding

## NetworkPolicy

Default deny + allow:

- DNS → `kube-system:53`
- Ingress-nginx → frontend `:3000` / backend `:8000`
- Backend → ChromaDB `:8000` + HTTPS `443` (public internet only)
- ChromaDB ← backend only

CI overlay strips NetworkPolicies for KIND port-forward smoke tests.

## Image pull policy

| Overlay | Policy |
|---------|--------|
| local / CI | `IfNotPresent` |
| prod | `Always` |

Helm: `imagePullPolicy` in values (set `Always` for prod releases).

## Verify

```bash
kubectl kustomize apps/overlays/local | rg -n "NetworkPolicy|ServiceAccount|readOnlyRootFilesystem|runAsNonRoot"
helm template juiceshop-chatbot ./helm -f helm/values-local.yaml --set backend.openai.apiKey=test | rg "NetworkPolicy|ServiceAccount"
```
