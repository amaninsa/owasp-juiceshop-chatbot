# Argo CD — App of Apps

## Quick start (KIND)

```bash
make kind-up
make argocd-install    # installs CRDs + server + UI ingress
make argocd-apply      # AppProject + root Application
make argocd-status
```

| Command | Purpose |
|---------|---------|
| `make argocd-install` | Namespace, stable install YAML (CRDs), wait, ingress, print password |
| `make argocd-apply` | Apply `argocd/` (fails clearly if CRDs missing) |
| `make argocd-password` | Initial `admin` password |
| `make argocd-ui` | Port-forward `:8081` |
| `make argocd-status` | Applications + pods |

UI: http://argocd.juiceshop-chatbot.local:8080  
(`127.0.0.1 argocd.juiceshop-chatbot.local` in `/etc/hosts`)

## Layout

- `project.yaml` — AppProject destinations (local/dev/prod/monitoring)
- `root-application.yaml` — App of Apps → `argocd/apps`
- `apps/*` — child Applications (auto-sync, prune, selfHeal)
- `ingress.yaml` — UI via ingress-nginx
- `patches/repo-server-local.yaml` — KIND: lower repo-server RAM + parallelism
- `patches/local-resources.yaml` — KIND: redis/server limits

`make argocd-install` also caps repo-server `emptyDir` sizeLimits (tmp/gpg/plugins/helm) so local container storage does not fill during GitOps syncs.

Full guide: [docs/gitops.md](../docs/gitops.md)
