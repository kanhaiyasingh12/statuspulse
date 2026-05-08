FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim AS runtime

ARG APP_ENV=production
ARG BUILD_VERSION=local
ARG BUILD_SHA=unknown

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/statuspulse/.local/bin:$PATH \
    APP_ENV=${APP_ENV} \
    BUILD_VERSION=${BUILD_VERSION} \
    BUILD_SHA=${BUILD_SHA}

WORKDIR /app

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system statuspulse \
    && useradd --system --gid statuspulse --create-home statuspulse

COPY --from=builder /root/.local /home/statuspulse/.local
COPY app ./app

RUN chown -R statuspulse:statuspulse /app /home/statuspulse

USER statuspulse

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:8000/health || exit 1

CMD ["gunicorn", "app.main:app", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000", "--workers", "2", "--timeout", "60"]
