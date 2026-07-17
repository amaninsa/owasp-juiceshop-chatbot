# Raw manifests (compatibility)

Canonical GitOps manifests live under `apps/base` with overlays in `apps/overlays/*`.

This directory keeps a thin Kustomize wrapper:

```bash
kubectl apply -k k8s/   # == apps/overlays/local
```

Prefer:

```bash
kubectl apply -k apps/overlays/local
# or
make deploy
```
