from __future__ import annotations

import os
import time
from functools import lru_cache
from typing import Any, Optional

from fastapi import FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from pydantic import BaseModel, Field

from assistant import ProductAssistant
from config import get_settings
from ingest import ingest
from observability import (
    CorrelationIdMiddleware,
    get_correlation_id,
    set_chroma_up,
    setup_logging,
    track_chat,
    track_ingest,
)
from products import find_products, load_products
from rag import get_chroma_client

setup_logging(
    level=os.getenv("LOG_LEVEL", "INFO"),
    json_logs=os.getenv("LOG_JSON", "true").lower() in {"1", "true", "yes"},
)

app = FastAPI(
    title="Juice Shop Product AI Assistant",
    description="RAG-powered AI assistant for OWASP Juice Shop product information and pricing.",
    version="1.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:4200",
        "http://127.0.0.1:4200",
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Correlation-ID", "X-Request-ID"],
)
app.add_middleware(CorrelationIdMiddleware)


@lru_cache
def get_assistant() -> ProductAssistant:
    return ProductAssistant()


class ChatMessage(BaseModel):
    role: str = Field(..., pattern="^(user|assistant)$")
    content: str


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, description="User question about products or pricing")
    history: list[ChatMessage] = Field(default_factory=list)


class ChatResponse(BaseModel):
    reply: str
    correlation_id: Optional[str] = None


class ProductResponse(BaseModel):
    id: int
    name: str
    description: str
    price: float
    deluxePrice: Optional[float] = None
    image: Optional[str] = None


class IngestResponse(BaseModel):
    status: str
    document_count: int


@app.get("/livez")
def livez() -> dict[str, str]:
    """Liveness: process is up (no dependency checks)."""
    return {"status": "alive"}


@app.get("/readyz")
def readyz() -> dict[str, Any]:
    """Readiness: ChromaDB is reachable."""
    try:
        get_chroma_client().heartbeat()
        set_chroma_up(True)
    except Exception as exc:  # noqa: BLE001
        set_chroma_up(False)
        raise HTTPException(status_code=503, detail=f"ChromaDB unavailable: {exc}") from exc
    return {"status": "ready"}


@app.get("/health")
def health() -> dict[str, Any]:
    """Backward-compatible aggregate health (used by local tooling)."""
    chroma_ok = False
    chroma_error = None
    try:
        get_chroma_client().heartbeat()
        chroma_ok = True
    except Exception as exc:  # noqa: BLE001
        chroma_error = str(exc)
    set_chroma_up(chroma_ok)
    return {
        "status": "ok" if chroma_ok else "degraded",
        "chroma": {"ok": chroma_ok, "error": chroma_error},
        "correlation_id": get_correlation_id(),
    }


@app.get("/metrics")
def metrics() -> Response:
    """Prometheus scrape endpoint."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/products", response_model=list[ProductResponse])
def list_products(
    q: Optional[str] = Query(default=None, description="Optional search query"),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[ProductResponse]:
    products = find_products(q or "", limit=limit) if q else list(load_products())[:limit]
    return [
        ProductResponse(
            id=product.id,
            name=product.name,
            description=product.description,
            price=product.price,
            deluxePrice=product.deluxe_price,
            image=product.image,
        )
        for product in products
    ]


@app.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: int) -> ProductResponse:
    for product in load_products():
        if product.id == product_id:
            return ProductResponse(
                id=product.id,
                name=product.name,
                description=product.description,
                price=product.price,
                deluxePrice=product.deluxe_price,
                image=product.image,
            )
    raise HTTPException(status_code=404, detail="Product not found")


@app.post("/ingest", response_model=IngestResponse)
def ingest_products(reset: bool = Query(default=False)) -> IngestResponse:
    """Embed Juice Shop products and upsert them into ChromaDB."""
    try:
        code = ingest(reset=reset)
        if code != 0:
            track_ingest("error")
            raise HTTPException(status_code=500, detail="Ingest failed")
        settings = get_settings()
        collection = get_chroma_client().get_or_create_collection(settings.chroma_collection)
        track_ingest("ok")
        return IngestResponse(status="ok", document_count=collection.count())
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        track_ingest("error")
        raise HTTPException(status_code=502, detail=f"Ingest failed: {exc}") from exc


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    started = time.perf_counter()
    try:
        history = [message.model_dump() for message in request.history]
        reply = get_assistant().ask(request.message, history=history)
        track_chat("ok", time.perf_counter() - started)
    except Exception as exc:  # noqa: BLE001
        track_chat("error", time.perf_counter() - started)
        raise HTTPException(status_code=502, detail=f"RAG chat failed: {exc}") from exc
    return ChatResponse(reply=reply, correlation_id=get_correlation_id())


def run() -> None:
    import uvicorn

    settings = get_settings()
    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=True,
    )


if __name__ == "__main__":
    run()
