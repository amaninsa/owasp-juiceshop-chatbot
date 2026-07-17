from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml

from config import get_settings

_HTML_TAG_RE = re.compile(r"<[^>]+>")


def strip_html(text: str) -> str:
    return _HTML_TAG_RE.sub(" ", text or "").replace("&nbsp;", " ").strip()


@dataclass(frozen=True)
class Product:
    id: int
    name: str
    description: str
    price: float
    deluxe_price: float | None
    image: str | None = None
    reviews: tuple[str, ...] = ()
    limit_per_user: int | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "price": self.price,
            "deluxePrice": self.deluxe_price,
            "image": self.image,
            "reviews": list(self.reviews),
            "limitPerUser": self.limit_per_user,
        }

    def catalog_line(self) -> str:
        deluxe = (
            f", deluxe price: ${self.deluxe_price:.2f}" if self.deluxe_price is not None else ""
        )
        return (
            f"- id={self.id} | {self.name} | price: ${self.price:.2f}{deluxe} | {self.description}"
        )

    def embedding_document(self) -> str:
        """Rich text document used for RAG embeddings."""
        parts = [
            f"Product ID: {self.id}",
            f"Name: {self.name}",
            f"Description: {strip_html(self.description)}",
            f"Price: ${self.price:.2f}",
        ]
        if self.deluxe_price is not None:
            parts.append(f"Deluxe price: ${self.deluxe_price:.2f}")
        if self.limit_per_user is not None:
            parts.append(f"Purchase limit per user: {self.limit_per_user}")
        if self.image:
            parts.append(f"Image: {self.image}")
        if self.reviews:
            parts.append("Customer reviews:")
            parts.extend(f"- {review}" for review in self.reviews)
        return "\n".join(parts)

    def metadata(self) -> dict[str, Any]:
        meta: dict[str, Any] = {
            "product_id": self.id,
            "name": self.name,
            "price": self.price,
            "image": self.image or "",
        }
        if self.deluxe_price is not None:
            meta["deluxe_price"] = self.deluxe_price
        if self.limit_per_user is not None:
            meta["limit_per_user"] = self.limit_per_user
        return meta


def _parse_products(raw_products: list[dict[str, Any]]) -> list[Product]:
    products: list[Product] = []
    for index, item in enumerate(raw_products, start=1):
        price = float(item.get("price") or 0)
        deluxe = item.get("deluxePrice")
        reviews_raw = item.get("reviews") or []
        reviews = tuple(
            f"{review.get('author', 'anonymous')}: {strip_html(str(review.get('text', '')))}"
            for review in reviews_raw
            if isinstance(review, dict)
        )
        products.append(
            Product(
                id=index,
                name=str(item.get("name", f"Product {index}")),
                description=str(item.get("description", "")),
                price=price,
                deluxe_price=float(deluxe) if deluxe is not None else None,
                image=item.get("image"),
                reviews=reviews,
                limit_per_user=item.get("limitPerUser"),
            )
        )
    return products


@lru_cache
def load_products(config_path: str | None = None) -> tuple[Product, ...]:
    path = Path(config_path or get_settings().products_config_path)
    with path.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    return tuple(_parse_products(data.get("products") or []))


def get_product_catalog_text(products: tuple[Product, ...] | None = None) -> str:
    catalog = products or load_products()
    return "\n".join(product.catalog_line() for product in catalog)


def find_products(query: str, limit: int = 10) -> list[Product]:
    needle = query.strip().lower()
    if not needle:
        return list(load_products())[:limit]

    scored: list[tuple[int, Product]] = []
    for product in load_products():
        haystack = f"{product.name} {product.description}".lower()
        if needle in haystack:
            score = 0 if needle in product.name.lower() else 1
            scored.append((score, product))
    scored.sort(key=lambda item: (item[0], item[1].name.lower()))
    return [product for _, product in scored[:limit]]
