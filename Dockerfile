# syntax=docker/dockerfile:1.7
# Multi-stage production image for OWASP Juice Shop Chatbot
#
# Builder: install ALL dependencies (including devDependencies) and compile.
# Runtime: distroless Node with production artifacts only.

############################
# 1) Builder — full deps + compile
############################
FROM node:24-bookworm AS builder

WORKDIR /juice-shop

# Force installation of devDependencies (TypeScript, @types/*, Cypress, Angular toolchain).
# Never set NODE_ENV=production before the build completes.
ENV NODE_ENV=development \
    npm_config_update_notifier=false \
    npm_config_fund=false \
    npm_config_audit=false \
    npm_config_omit=

# Manifests first for layer caching
COPY package.json ./
COPY frontend/package.json ./frontend/

# Install ALL dependencies for root + frontend.
# Prefer npm ci when lockfiles are present; otherwise npm install (this repo has no lockfiles).
# --ignore-scripts skips postinstall until sources are copied; rebuild native modules after.
RUN if [ -f package-lock.json ]; then \
      npm ci --include=dev --ignore-scripts; \
    else \
      npm install --include=dev --ignore-scripts; \
    fi \
 && npm rebuild sqlite3 \
 && cd frontend \
 && if [ -f package-lock.json ]; then \
      npm ci --include=dev --ignore-scripts; \
    else \
      npm install --include=dev --ignore-scripts; \
    fi

# Application sources (node_modules / dist excluded via .dockerignore)
COPY . .

# Compile frontend (Angular) then server (TypeScript) — requires full deps above
RUN npm run build:frontend \
 && npm run build:server

# Only AFTER a successful build: drop build tooling and assemble runtime payload
RUN npm prune --omit=dev \
 && npm dedupe --omit=dev \
 && rm -rf frontend/node_modules frontend/.angular frontend/src \
 && mkdir -p /out/logs /out/frontend \
 && cp -a package.json swagger.yml /out/ \
 && cp -a build data config views ftp i18n encryptionkeys node_modules /out/ \
 && cp -a frontend/dist /out/frontend/ \
 && cp -a .well-known /out/ \
 && rm -f /out/ftp/legal.md /out/i18n/*.json \
 && chown -R 65532:0 /out \
 && chmod -R g=u /out/logs /out/ftp /out/frontend/dist /out/data /out/i18n /out/build

############################
# 2) Runtime — production artifacts only
############################
FROM gcr.io/distroless/nodejs24-debian13 AS runtime

ARG BUILD_DATE
ARG VCS_REF
ARG PORT=3000
ARG VERSION=20.1.1

LABEL org.opencontainers.image.title="OWASP Juice Shop Chatbot" \
      org.opencontainers.image.description="Juice Shop frontend + Node API with embedded AI chat widget" \
      org.opencontainers.image.authors="amaninsa" \
      org.opencontainers.image.vendor="amaninsa" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.url="https://github.com/amaninsa/owasp-juiceshop-chatbot" \
      org.opencontainers.image.source="https://github.com/amaninsa/owasp-juiceshop-chatbot" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

WORKDIR /juice-shop

COPY --from=builder --chown=65532:0 /out/ .

USER 65532

ENV PORT=${PORT} \
    NODE_ENV=production

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["/nodejs/bin/node", "-e", "require('http').get('http://127.0.0.1:'+(process.env.PORT||3000)+'/',r=>process.exit(r.statusCode<500?0:1)).on('error',()=>process.exit(1))"]

CMD ["/juice-shop/build/app.js"]
