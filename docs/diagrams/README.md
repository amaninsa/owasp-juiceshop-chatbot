# Mermaid diagram sources

Standalone `.mmd` files for PNG/SVG export (GitHub README embeds Mermaid in Markdown; recruiters often want PNGs for LinkedIn).

| File | Diagram |
|------|---------|
| `platform-overview.mmd` | Developer → GitHub → Actions → GHCR → Argo CD → K8s → Obs |
| `cicd-flow.mmd` | CI → build → push → GitOps |
| `observability-flow.mmd` | Metrics + logs → Grafana / Alertmanager |

## Export PNG

```bash
./docs/diagrams/export-png.sh
# or paste into https://mermaid.live → Actions → PNG
```

Also rendered inline in [`../architecture.md`](../architecture.md).
