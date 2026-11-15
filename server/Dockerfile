# syntax=docker/dockerfile:1

# ── Bauen ──
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY web/package.json web/package-lock.json ./web/
RUN npm ci --prefix web
COPY tsconfig.json ./
COPY src ./src
COPY web ./web
RUN npm run build && npm prune --omit=dev

# ── Betrieb: nur Laufzeit, unprivilegierter Benutzer ──
FROM node:24-bookworm-slim
ENV NODE_ENV=production \
    SENTINEL_HOST=0.0.0.0 \
    SENTINEL_PORT=8790 \
    SENTINEL_DATA_DIR=/data \
    SENTINEL_WEB_DIR=/app/web
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/web/dist ./web
COPY package.json ./
RUN mkdir /data && chown 10001:10001 /data
USER 10001:10001
VOLUME /data
EXPOSE 8790 5013
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8790/api/v1/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "--disable-warning=ExperimentalWarning", "dist/index.js"]
