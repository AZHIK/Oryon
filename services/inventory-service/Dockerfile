# syntax=docker/dockerfile:1.7
FROM python:3.12-slim-bookworm AS builder

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install uv==0.12.12

ENV UV_LINK_MODE=copy \
    UV_HTTP_TIMEOUT=600 \
    UV_CONCURRENT_DOWNLOADS=4

WORKDIR /app

COPY pyproject.toml uv.lock README.md ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

FROM python:3.12-slim-bookworm AS development

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install uv==0.12.12

ENV UV_LINK_MODE=copy \
    UV_HTTP_TIMEOUT=600 \
    UV_CONCURRENT_DOWNLOADS=4

WORKDIR /app

COPY pyproject.toml uv.lock README.md ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project
COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen && chmod -R a+w /app

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

FROM python:3.12-slim-bookworm AS runtime

# Fixed UID/GID so host volume and Docker-secret ownership is predictable.
RUN groupadd -r -g 10001 oryonfoods && useradd -r -u 10001 -g oryonfoods -d /app oryonfoods

# Apply Debian security updates already present in the base image. The slim
# tag floats, but its cached libcrypto/libssl can lag the security archive;
# without this the image keeps shipping a base-layer OpenSSL that Trivy flags
# as fixed upstream (e.g. CVE-2026-84782 in libssl3/openssl).
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app /app
RUN rm -rf /app/tests /app/.pytest_cache /app/.ruff_cache /app/uv.lock

# JWT public keys are mounted at runtime and must never be baked into the
# image. The build fails closed if a key accidentally enters the context.
RUN if [ -d /app/keys ] && [ -n "$(find /app/keys -type f -name '*.pem' -print -quit)" ]; then \
        echo "Refusing to build: key material found in /app/keys. Mount keys at runtime instead." >&2; \
        exit 1; \
    fi

RUN mkdir -p /var/lib/oryonfoods/item_images && chown -R oryonfoods:oryonfoods /var/lib/oryonfoods

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
USER oryonfoods

EXPOSE 8100

HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD python -c "import http.client; c=http.client.HTTPConnection('localhost',8100); c.request('GET','/health'); r=c.getresponse(); exit(0) if r.status==200 else exit(1)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8100", "--proxy-headers", "--forwarded-allow-ips", "*"]
