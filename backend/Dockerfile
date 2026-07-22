# syntax=docker/dockerfile:1.7
# Production multi-stage image for Juice Shop AI Assistant (FastAPI + RAG)

############################
# Builder — install deps
############################
FROM python:3.11-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential curl \
  && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

COPY ai-assistant/requirements.txt /build/requirements.txt
RUN pip install --upgrade pip \
  && pip install -r /build/requirements.txt

############################
# Runtime — minimal, non-root
############################
FROM python:3.11-slim-bookworm AS runtime

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.1.0

LABEL org.opencontainers.image.title="Juice Shop AI Assistant" \
      org.opencontainers.image.description="RAG-powered FastAPI assistant for OWASP Juice Shop products" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/juice-shop/juice-shop"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}" \
    PRODUCTS_CONFIG_PATH=/data/config/default.yml \
    CHROMA_HOST=chromadb \
    CHROMA_PORT=8000 \
    API_HOST=0.0.0.0 \
    API_PORT=8000 \
    INGEST_ON_STARTUP=true \
    CHROMA_WAIT_TIMEOUT_SECONDS=120

# curl is used by entrypoint wait-loop and Docker HEALTHCHECK
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --gid 10001 appgroup \
  && useradd --uid 10001 --gid appgroup --create-home --shell /usr/sbin/nologin appuser

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app

COPY --chown=appuser:appgroup ai-assistant/ /app/
COPY --chown=appuser:appgroup config/default.yml /data/config/default.yml
COPY --chown=appuser:appgroup ai-assistant/entrypoint.sh /entrypoint.sh

RUN chmod 755 /entrypoint.sh \
  && mkdir -p /tmp/app \
  && chown -R appuser:appgroup /app /data /tmp/app

USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${API_PORT}/livez" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
