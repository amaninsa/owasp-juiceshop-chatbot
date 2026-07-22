from __future__ import annotations

from typing import Any

import chromadb
from chromadb.api.models.Collection import Collection
from openai import OpenAI

from config import get_settings


class OpenAIEmbedder:
    def __init__(self) -> None:
        settings = get_settings()
        self.client = OpenAI(api_key=settings.open_ai_key)
        self.model = settings.openai_embedding_model

    def embed_documents(self, texts: list[str]) -> list[list[float]]:
        if not texts:
            return []
        response = self.client.embeddings.create(model=self.model, input=texts)
        # API returns embeddings in input order
        return [item.embedding for item in response.data]

    def embed_query(self, text: str) -> list[float]:
        return self.embed_documents([text])[0]


def get_chroma_client(
    host: str | None = None,
    port: int | None = None,
) -> Any:
    """Return a ChromaDB HTTP client (typed as Any — chromadb stubs are incomplete)."""
    settings = get_settings()
    return chromadb.HttpClient(
        host=host or settings.chroma_host,
        port=port or settings.chroma_port,
    )


def get_or_create_collection(
    client: Any | None = None,
    name: str | None = None,
) -> Collection:
    settings = get_settings()
    chroma = client or get_chroma_client()
    return chroma.get_or_create_collection(
        name=name or settings.chroma_collection,
        metadata={"hnsw:space": "cosine"},
    )


class ProductRetriever:
    """Retrieve relevant product documents from ChromaDB for RAG."""

    def __init__(self) -> None:
        settings = get_settings()
        self.top_k = settings.rag_top_k
        self.embedder = OpenAIEmbedder()
        self.collection = get_or_create_collection()

    def retrieve(self, query: str, top_k: int | None = None) -> list[dict[str, Any]]:
        k = top_k or self.top_k
        query_embedding = self.embedder.embed_query(query)
        results = self.collection.query(
            query_embeddings=[query_embedding],  # type: ignore[arg-type]
            n_results=k,
            include=["documents", "metadatas", "distances"],  # type: ignore[list-item]
        )

        documents = (results.get("documents") or [[]])[0]
        metadatas = (results.get("metadatas") or [[]])[0]
        distances = (results.get("distances") or [[]])[0]
        ids = (results.get("ids") or [[]])[0]

        retrieved: list[dict[str, Any]] = []
        for index, doc_id in enumerate(ids):
            retrieved.append(
                {
                    "id": doc_id,
                    "document": documents[index] if index < len(documents) else "",
                    "metadata": metadatas[index] if index < len(metadatas) else {},
                    "distance": distances[index] if index < len(distances) else None,
                }
            )
        return retrieved

    def format_context(self, retrieved: list[dict[str, Any]]) -> str:
        if not retrieved:
            return "No matching products found in the knowledge base."

        blocks = []
        for item in retrieved:
            blocks.append(item["document"])
        return "\n\n---\n\n".join(blocks)
