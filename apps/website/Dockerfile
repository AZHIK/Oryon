# ─────────────────────────────────────────────────────────────
# Oryon website image
#
# Build stage produces the Next.js static export, runtime stage serves
# `out/` from a non-root Nginx. No Node runtime is shipped.
# ─────────────────────────────────────────────────────────────
FROM node:24.22.1-bookworm-slim AS deps

WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund


FROM node:24.22.1-bookworm-slim AS build

WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# Public, build-time-only analytics switch. Empty means no analytics script.
ARG NEXT_PUBLIC_PLAUSIBLE_DOMAIN=""
ENV NEXT_PUBLIC_PLAUSIBLE_DOMAIN=$NEXT_PUBLIC_PLAUSIBLE_DOMAIN

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build


FROM nginxinc/nginx-unprivileged:1.31.7-alpine3.24 AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/out /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
