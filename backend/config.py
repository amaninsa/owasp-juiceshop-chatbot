from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT_DIR = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT_DIR / ".env.openai"

if ENV_FILE.exists():
    load_dotenv(ENV_FILE)


class Settings(BaseSettings):
    open_ai_key: str
    openai_model: str = "gpt-4o-mini"
    openai_embedding_model: str = "text-embedding-3-small"
    products_config_path: Path = ROOT_DIR / "config" / "default.yml"
    assistant_name: str = "Juice Shop Product Assistant"
    api_host: str = "0.0.0.0"
    api_port: int = 8000

    # ChromaDB connection (Docker service name in compose)
    chroma_host: str = "localhost"
    chroma_port: int = 8001
    chroma_collection: str = "juice_shop_products"
    rag_top_k: int = 5

    # Container / ops knobs
    ingest_on_startup: bool = True
    chroma_wait_timeout_seconds: int = 120

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE) if ENV_FILE.exists() else None,
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
