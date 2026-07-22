# Optional thin wrapper around official ChromaDB for consistent labels + healthcheck.
# Prefer the upstream image; this exists so compose/K8s can pin a project-owned tag later.
FROM chromadb/chroma:0.5.23

LABEL org.opencontainers.image.title="OWASP JuiceShop Chatbot ChromaDB" \
      org.opencontainers.image.description="Vector database for OWASP JuiceShop Chatbot RAG" \
      org.opencontainers.image.source="https://github.com/amaninsa/owasp-juiceshop-chatbot"

# Upstream image owns /chroma as root; make log + data dirs writable for non-root (UID 1000).
# Also patch known CRITICAL OS / Python transitive CVEs flagged by Trivy in CI/CD.
USER root
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && mkdir -p /chroma/chroma \
 && touch /chroma/chroma.log \
 && chown -R 1000:1000 /chroma \
 && (python -m pip install --no-cache-dir 'h11>=0.16.0' || pip3 install --no-cache-dir 'h11>=0.16.0' || true) \
 && rm -rf /var/lib/apt/lists/*
USER 1000

# Chroma images include Python; use it for a dependency-free health probe.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/v1/heartbeat', timeout=3)"
