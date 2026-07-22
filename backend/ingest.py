#!/usr/bin/env python3
"""Ingest Juice Shop product data into ChromaDB as embeddings."""

from __future__ import annotations

import argparse
import sys

from config import get_settings
from products import Product, load_products
from rag import OpenAIEmbedder, get_chroma_client, get_or_create_collection


def build_payload(products: list[Product]):
    ids = [f"product-{product.id}" for product in products]
    documents = [product.embedding_document() for product in products]
    metadatas = [product.metadata() for product in products]
    return ids, documents, metadatas


def ingest(reset: bool = False) -> int:
    settings = get_settings()
    products = list(load_products())
    if not products:
        print("No products found to ingest.", file=sys.stderr)
        return 1

    client = get_chroma_client()
    heartbeat = client.heartbeat()
    print(
        "Connected to ChromaDB at "
        f"{settings.chroma_host}:{settings.chroma_port} "
        f"(heartbeat={heartbeat})"
    )

    if reset:
        try:
            client.delete_collection(settings.chroma_collection)
            print(f"Deleted existing collection: {settings.chroma_collection}")
        except Exception:  # noqa: BLE001
            pass

    collection = get_or_create_collection(client)
    ids, documents, metadatas = build_payload(products)

    print(f"Embedding {len(documents)} products with {settings.openai_embedding_model}...")
    embedder = OpenAIEmbedder()
    embeddings = embedder.embed_documents(documents)

    # Upsert in batches to stay within embedding/API limits
    batch_size = 50
    for start in range(0, len(ids), batch_size):
        end = start + batch_size
        collection.upsert(
            ids=ids[start:end],
            documents=documents[start:end],
            metadatas=metadatas[start:end],
            embeddings=embeddings[start:end],  # type: ignore[arg-type]
        )
        print(f"  upserted {min(end, len(ids))}/{len(ids)}")

    print(
        f'Done. Collection "{settings.chroma_collection}" now has {collection.count()} documents.'
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Ingest Juice Shop products into ChromaDB")
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Delete and recreate the collection before ingesting",
    )
    args = parser.parse_args()
    return ingest(reset=args.reset)


if __name__ == "__main__":
    raise SystemExit(main())
