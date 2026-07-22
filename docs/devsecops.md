# DevSecOps

Security gates for the Juice Shop AI platform. Primary workflow: [`security.yml`](../.github/workflows/security.yml). Image scans also run inside the reusable build workflow before GHCR push.

## Gates

| Control | Tool | Fail policy |
|---------|------|-------------|
| Secrets | Gitleaks | Fail |
| Filesystem vulns | Trivy FS | CRITICAL/HIGH |
| IaC | Trivy config | CRITICAL/HIGH |
| Container images | Trivy image | CRITICAL/HIGH (pre-push) |
| Dependencies (PR) | Dependency Review | high+ |
| SAST | CodeQL (JS/TS + Python) | Upload + gate |

## Token & permissions model

- Prefer **`GITHUB_TOKEN`** (no PAT) for GHCR push and GitOps commits.
- Key permissions: `contents`, `packages: write`, `id-token: write`, `security-events: write`.
- CD uses `contents: write` only to push Kustomize updates; deploy remains Argo CD.

## Related

- [`github-actions.md`](./github-actions.md)
- [`cicd.md`](./cicd.md)
- [`security.md`](./security.md)
