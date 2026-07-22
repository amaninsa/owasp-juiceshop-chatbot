# CI/CD summary

Canonical deep dive: [`github-actions.md`](./github-actions.md)

## Pipelines

| Workflow | Trigger | Outcome |
|----------|---------|---------|
| `ci.yml` | Pull request | Lint/test + GHCR SHA images |
| `cd.yml` | Push to `main` | GHCR + Kustomize bump + Argo CD |
| `security.yml` | PR / push / weekly | DevSecOps gates |
| `release.yml` | Tag `v*` | GitHub Release + versioned images |

## Flow

```text
Git Push (PR)
  → ci.yml + security.yml
  → GHCR (SHA)

Merge to main
  → cd.yml
  → GHCR (SHA + main)
  → kustomize edit set image (apps/overlays/local)
  → Git commit [skip ci]
  → Argo CD auto-sync
  → Kubernetes

Tag v*
  → release.yml
  → GHCR (SHA + version)
  → GitHub Release
```

**Never:** `kubectl apply` from GitHub Actions for application deploy.  
**Always:** desired state in Git; Argo CD reconciles the cluster.
