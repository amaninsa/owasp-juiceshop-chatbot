"""Unit tests for Juice Shop AI assistant (no live OpenAI/Chroma required)."""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="session", autouse=True)
def _test_env() -> None:
    # Ensure settings can load even without .env.openai in CI
    os.environ.setdefault("OPEN_AI_KEY", "test-key-not-used")
    os.environ.setdefault(
        "PRODUCTS_CONFIG_PATH",
        str(Path(__file__).resolve().parents[2] / "config" / "default.yml"),
    )
    # Avoid accidental Chroma calls during import of get_settings
    os.environ.setdefault("CHROMA_HOST", "127.0.0.1")
    os.environ.setdefault("CHROMA_PORT", "1")


def test_load_products() -> None:
    from products import load_products

    products = load_products()
    assert len(products) > 0
    assert products[0].name
    assert products[0].price >= 0


def test_find_products_apple() -> None:
    from products import find_products

    matches = find_products("apple", limit=5)
    assert any("Apple" in p.name for p in matches)


def test_livez_endpoint() -> None:
    from main import app

    client = TestClient(app)
    response = client.get("/livez")
    assert response.status_code == 200
    assert response.json()["status"] == "alive"


def test_health_degraded_without_chroma() -> None:
    from main import app

    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert "status" in body
    assert "chroma" in body


def test_embedding_document_contains_price() -> None:
    from products import load_products

    doc = load_products()[0].embedding_document()
    assert "Price:" in doc
    assert "Name:" in doc
