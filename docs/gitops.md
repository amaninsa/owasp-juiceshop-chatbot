# GitOps (ArgoCD + Kustomize)

## Layout

```
apps/
  base/                 # canonical manifests (copied from original k8s/)
  overlays/
    local/              # KIND (local images + hostPath PV)
    dev/                # ghcr.dev tags, standard StorageClass
    prod/               # pinned versions, gp2, 3 replicas
argocd/
  project.yaml
  application-local.yaml
  application-dev.yaml
  application-prod.yaml
  kustomization.yaml
k8s/
  kustomization.yaml    # compatibility wrapper → apps/overlays/local
```

## Sync policy

All Applications enable:

- `automated.prune: true`
- `automated.selfHeal: true`
- `CreateNamespace=true`

## Bootstrap ArgoCD on KIND (optional)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods, then register apps (edit repoURL first!)
kubectl apply -k argocd/
```

## Point Applications at your fork

Edit `repoURL` / `targetRevision` in:

- `argocd/application-local.yaml`
- `argocd/application-dev.yaml`
- `argocd/application-prod.yaml`

## Secrets (never committed)

```bash
kubectl -n juiceshop-chatbot create secret generic juiceshop-chatbot-secrets \
  --from-literal=OPEN_AI_KEY="sk-..." \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Validate overlays without ArgoCD

```bash
kubectl kustomize apps/overlays/local
kubectl kustomize apps/overlays/dev
kubectl kustomize apps/overlays/prod
```

## Flow

1. PR merges to `develop` / `main`
2. ArgoCD detects Git change
3. Auto-sync applies Kustomize overlay
4. Self-heal reverts manual cluster drift
5. Prune removes deleted manifests

## Related docs

- [KIND deployment](kind-deployment.md)
- [Helm](helm.md)
- [CI/CD](ci-cd.md)
