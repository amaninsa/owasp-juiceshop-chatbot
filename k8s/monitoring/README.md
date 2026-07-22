# Local KIND Observability Stack

Pure Kubernetes YAML (Kustomize) observability for the Juice Shop Chatbot KIND cluster.

## Profiles

| Profile | Path | Storage | Retention | Use when |
|---------|------|---------|-----------|----------|
| **local** (default) | `k8s/monitoring/local` | emptyDir + sizeLimits | 24h / 512MB Prometheus | KIND demos, portfolio |
| **production** | `k8s/monitoring/production` | PVC | Prometheus 15d / Loki 7d | Cloud / longer retention |

```bash
make monitoring                 # local profile
make monitoring-production      # PVC profile
# or: MONITORING_PROFILE=production make monitoring
```

## Components

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| Prometheus | `monitoring` | Metrics scrape + alert evaluation |
| Grafana | `monitoring` | Dashboards (ConfigMap-provisioned) |
| Alertmanager | `monitoring` | Alert routing (UI for local) |
| Loki | `monitoring` | Log aggregation (filesystem + compactor) |
| Promtail | `monitoring` | Pod log shipper (emptyDir positions) |
| kube-state-metrics | `monitoring` | Kubernetes object metrics |
| Node Exporter | `monitoring` | Host / node metrics |
| cAdvisor | `monitoring` | **Production profile only** (disabled on local KIND) |

## Quick start

```bash
make doctor
make kind-up
make deploy
make monitoring
```

## URLs (KIND ingress on `:8080`)

Add to `/etc/hosts`:

```text
127.0.0.1 juiceshop-chatbot.local
127.0.0.1 grafana.juiceshop-chatbot.local
127.0.0.1 prometheus.juiceshop-chatbot.local
127.0.0.1 alertmanager.juiceshop-chatbot.local
```

| UI | URL | Default login |
|----|-----|----------------|
| Grafana | http://grafana.juiceshop-chatbot.local:8080 | `admin` / `admin` (anonymous Viewer enabled) |
| Prometheus | http://prometheus.juiceshop-chatbot.local:8080 | — |
| Alertmanager | http://alertmanager.juiceshop-chatbot.local:8080 | — |

Loki is **not** publicly exposed; use Grafana Explore or `make monitoring-port-forward`.

## Layout

```text
k8s/monitoring/
├── kustomization.yaml      # → local (default)
├── base/                   # shared manifests
├── local/                  # emptyDir, 24h, low resources
└── production/             # PVC + longer retention
```

## Make targets

```bash
make doctor                  # Docker / KIND / disk / namespace health
make monitoring              # apply local profile
make monitoring-production   # apply production profile
make monitoring-status
make monitoring-port-forward
make monitoring-delete
make clean                   # reclaim emptyDir + dangling Docker layers
```

See [docs/monitoring.md](../../docs/monitoring.md) for architecture and troubleshooting.
