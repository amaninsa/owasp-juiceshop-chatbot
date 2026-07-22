"""Observability: structured logging, correlation IDs, Prometheus metrics."""

from __future__ import annotations

import json
import logging
import sys
import time
import uuid
from contextvars import ContextVar
from typing import Callable, Optional

from prometheus_client import Counter, Gauge, Histogram
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp

CORRELATION_HEADER = "X-Correlation-ID"
REQUEST_ID_HEADER = "X-Request-ID"

correlation_id_var: ContextVar[str] = ContextVar("correlation_id", default="-")

# Application metrics (scraped via /metrics alongside instrumentator defaults)
CHAT_REQUESTS = Counter(
    "juiceshop_chatbot_chat_requests_total",
    "Total /chat requests",
    ["status"],
)
CHAT_LATENCY = Histogram(
    "juiceshop_chatbot_chat_latency_seconds",
    "Latency of /chat requests",
    buckets=(0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0),
)
INGEST_REQUESTS = Counter(
    "juiceshop_chatbot_ingest_requests_total",
    "Total /ingest requests",
    ["status"],
)
CHROMA_UP = Gauge(
    "juiceshop_chatbot_chroma_up",
    "1 if ChromaDB heartbeat succeeded on last health check, else 0",
)
HTTP_REQUESTS = Counter(
    "juiceshop_chatbot_http_requests_total",
    "HTTP requests handled by the AI backend",
    ["method", "path", "status"],
)
HTTP_LATENCY = Histogram(
    "juiceshop_chatbot_http_request_duration_seconds",
    "HTTP request duration",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)


class JsonLogFormatter(logging.Formatter):
    """Emit one JSON object per log line (correlation_id included)."""

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "correlation_id": correlation_id_var.get(),
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        for key in ("method", "path", "status_code", "duration_ms"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        return json.dumps(payload, ensure_ascii=True)


def setup_logging(*, level: str = "INFO", json_logs: bool = True) -> None:
    """Configure root + uvicorn loggers once."""
    root = logging.getLogger()
    if getattr(root, "_juiceshop_chatbot_configured", False):
        return

    root.handlers.clear()
    handler = logging.StreamHandler(sys.stdout)
    if json_logs:
        handler.setFormatter(JsonLogFormatter())
    else:
        handler.setFormatter(
            logging.Formatter(
                "%(asctime)s %(levelname)s [%(name)s] [cid=%(correlation_id)s] %(message)s"
            )
        )
        # Inject correlation_id into every record for text format
        old_factory = logging.getLogRecordFactory()

        def record_factory(*args: object, **kwargs: object) -> logging.LogRecord:
            record = old_factory(*args, **kwargs)
            record.correlation_id = correlation_id_var.get()  # type: ignore[attr-defined]
            return record

        logging.setLogRecordFactory(record_factory)

    root.addHandler(handler)
    root.setLevel(getattr(logging, level.upper(), logging.INFO))

    for name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        logging.getLogger(name).handlers = []
        logging.getLogger(name).propagate = True

    root._juiceshop_chatbot_configured = True  # type: ignore[attr-defined]


def get_correlation_id() -> str:
    return correlation_id_var.get()


def _extract_or_create_correlation_id(request: Request) -> str:
    for header in (CORRELATION_HEADER, REQUEST_ID_HEADER):
        value = request.headers.get(header)
        if value and value.strip():
            return value.strip()[:128]
    return str(uuid.uuid4())


def _normalize_path(path: str) -> str:
    """Collapse dynamic product IDs to keep metric cardinality low."""
    parts = path.strip("/").split("/")
    if len(parts) >= 2 and parts[0] == "products" and parts[1].isdigit():
        return "/products/{id}"
    if path.startswith("/metrics"):
        return "/metrics"
    return path.split("?")[0] or "/"


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    """Attach correlation IDs and emit structured access logs + HTTP metrics."""

    def __init__(self, app: ASGIApp, exclude_paths: Optional[set[str]] = None) -> None:
        super().__init__(app)
        self.exclude_paths = exclude_paths or {"/metrics", "/livez"}

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        cid = _extract_or_create_correlation_id(request)
        token = correlation_id_var.set(cid)
        started = time.perf_counter()
        logger = logging.getLogger("juiceshop_chatbot.access")
        path = _normalize_path(request.url.path)
        method = request.method

        try:
            response = await call_next(request)
        except Exception:
            duration_ms = round((time.perf_counter() - started) * 1000, 2)
            HTTP_REQUESTS.labels(method=method, path=path, status="500").inc()
            HTTP_LATENCY.labels(method=method, path=path).observe(time.perf_counter() - started)
            logger.exception(
                "request failed",
                extra={
                    "method": method,
                    "path": path,
                    "status_code": 500,
                    "duration_ms": duration_ms,
                },
            )
            correlation_id_var.reset(token)
            raise

        duration = time.perf_counter() - started
        duration_ms = round(duration * 1000, 2)
        status = str(response.status_code)

        if request.url.path not in self.exclude_paths:
            HTTP_REQUESTS.labels(method=method, path=path, status=status).inc()
            HTTP_LATENCY.labels(method=method, path=path).observe(duration)
            logger.info(
                "request completed",
                extra={
                    "method": method,
                    "path": path,
                    "status_code": response.status_code,
                    "duration_ms": duration_ms,
                },
            )

        response.headers[CORRELATION_HEADER] = cid
        response.headers[REQUEST_ID_HEADER] = cid
        correlation_id_var.reset(token)
        return response


def track_chat(status: str, duration_seconds: float) -> None:
    CHAT_REQUESTS.labels(status=status).inc()
    CHAT_LATENCY.observe(duration_seconds)


def track_ingest(status: str) -> None:
    INGEST_REQUESTS.labels(status=status).inc()


def set_chroma_up(ok: bool) -> None:
    CHROMA_UP.set(1 if ok else 0)
