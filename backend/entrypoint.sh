#!/bin/sh
set -eu

API_HOST="${API_HOST:-0.0.0.0}"
API_PORT="${API_PORT:-8000}"
CHROMA_HOST="${CHROMA_HOST:-chromadb}"
CHROMA_PORT="${CHROMA_PORT:-8000}"
INGEST_ON_STARTUP="${INGEST_ON_STARTUP:-true}"
CHROMA_WAIT_TIMEOUT_SECONDS="${CHROMA_WAIT_TIMEOUT_SECONDS:-120}"
INGEST_RESET="${INGEST_RESET:-true}"

echo "[entrypoint] Waiting for ChromaDB at ${CHROMA_HOST}:${CHROMA_PORT} (timeout=${CHROMA_WAIT_TIMEOUT_SECONDS}s)..."
elapsed=0
until curl -sf "http://${CHROMA_HOST}:${CHROMA_PORT}/api/v1/heartbeat" >/dev/null 2>&1; do
  elapsed=$((elapsed + 2))
  if [ "${elapsed}" -ge "${CHROMA_WAIT_TIMEOUT_SECONDS}" ]; then
    echo "[entrypoint] ERROR: ChromaDB not ready after ${CHROMA_WAIT_TIMEOUT_SECONDS}s" >&2
    exit 1
  fi
  sleep 2
done
echo "[entrypoint] ChromaDB is ready."

if [ "${INGEST_ON_STARTUP}" = "true" ] || [ "${INGEST_ON_STARTUP}" = "1" ]; then
  echo "[entrypoint] Ingesting Juice Shop products into ChromaDB..."
  if [ "${INGEST_RESET}" = "true" ] || [ "${INGEST_RESET}" = "1" ]; then
    python ingest.py --reset
  else
    python ingest.py
  fi
else
  echo "[entrypoint] Skipping ingest (INGEST_ON_STARTUP=${INGEST_ON_STARTUP})."
fi

echo "[entrypoint] Starting AI assistant on ${API_HOST}:${API_PORT}..."
exec uvicorn main:app --host "${API_HOST}" --port "${API_PORT}" --proxy-headers --forwarded-allow-ips='*'
