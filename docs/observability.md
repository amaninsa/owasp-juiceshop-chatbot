# Observability

## Health endpoints

| Path | Purpose |
|------|---------|
| `GET /livez` | Liveness — process up (no deps) |
| `GET /readyz` | Readiness — ChromaDB heartbeat |
| `GET /health` | Aggregate status (`ok` / `degraded`) + correlation id |

Kubernetes probes already use `/livez` and `/readyz`.

## Prometheus metrics

`GET /metrics` — Prometheus text exposition.

Pod annotations (already on backend Deployment):

```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "8000"
prometheus.io/path: "/metrics"
```

### Custom metrics

| Metric | Type | Description |
|--------|------|-------------|
| `juiceshop_chatbot_http_requests_total` | Counter | HTTP by method/path/status |
| `juiceshop_chatbot_http_request_duration_seconds` | Histogram | HTTP latency |
| `juiceshop_chatbot_chat_requests_total` | Counter | `/chat` by status |
| `juiceshop_chatbot_chat_latency_seconds` | Histogram | `/chat` latency |
| `juiceshop_chatbot_ingest_requests_total` | Counter | `/ingest` by status |
| `juiceshop_chatbot_chroma_up` | Gauge | Last Chroma health (0/1) |

## Structured logging

JSON logs to stdout (default):

```json
{"timestamp":"...","level":"INFO","logger":"juiceshop_chatbot.access","message":"request completed","correlation_id":"...","method":"GET","path":"/health","status_code":200,"duration_ms":1.2}
```

Env knobs:

| Variable | Default | Meaning |
|----------|---------|---------|
| `LOG_LEVEL` | `INFO` | Python log level |
| `LOG_JSON` | `true` | JSON vs text format |

## Correlation IDs

- Incoming: `X-Correlation-ID` or `X-Request-ID` (else UUID generated)
- Outgoing: both headers echoed on every response
- Included in structured logs and `/health` / `/chat` payloads

## Grafana

Import [`monitoring/grafana-ai-assistant-dashboard.json`](../monitoring/grafana-ai-assistant-dashboard.json).

Panels: HTTP rate/latency, Chroma up, chat rate/latency, ingest, 5xx rate.

The existing Juice Shop challenge dashboard (`monitoring/grafana-dashboard.json`) is unchanged.
