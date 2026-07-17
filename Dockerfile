# Multi-stage production image for OWASP Juice Shop (upstream pattern preserved).
# Stage 1 builds the app; stage 2 is a minimal distroless runtime running as non-root.

FROM node:24 AS installer
COPY . /juice-shop
WORKDIR /juice-shop
RUN npm install -g typescript@^6.0.3 \
  && npm install --omit=dev \
  && npm dedupe --omit=dev \
  && rm -rf frontend/node_modules frontend/.angular frontend/src/assets \
  && mkdir logs \
  && chown -R 65532 logs \
  && chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/ \
  && chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/ \
  && rm -f ftp/legal.md \
  && rm -f i18n/*.json

# keep version in sync with package.json
ARG CYCLONEDX_NPM_VERSION='^2.0.0||^3.0.0||^4.0.0'
RUN npm install -g @cyclonedx/cyclonedx-npm@$CYCLONEDX_NPM_VERSION \
  && npm run sbom

FROM gcr.io/distroless/nodejs24-debian13
ARG BUILD_DATE
ARG VCS_REF
ARG PORT=3000
LABEL maintainer="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
    org.opencontainers.image.title="OWASP Juice Shop" \
    org.opencontainers.image.description="Probably the most modern and sophisticated insecure web application" \
    org.opencontainers.image.authors="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
    org.opencontainers.image.vendor="Open Worldwide Application Security Project" \
    org.opencontainers.image.documentation="https://help.owasp-juice.shop" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.version="20.1.1" \
    org.opencontainers.image.url="https://owasp-juice.shop" \
    org.opencontainers.image.source="https://github.com/juice-shop/juice-shop" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE
WORKDIR /juice-shop
COPY --from=installer --chown=65532:0 /juice-shop .
USER 65532
ENV PORT=${PORT} \
    NODE_ENV=production
EXPOSE ${PORT}
# Distroless has no shell/curl — probe with the Node runtime itself.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["/nodejs/bin/node", "-e", "require('http').get('http://127.0.0.1:'+(process.env.PORT||3000)+'/',r=>process.exit(r.statusCode<500?0:1)).on('error',()=>process.exit(1))"]
CMD ["/juice-shop/build/app.js"]
