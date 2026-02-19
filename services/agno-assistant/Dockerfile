FROM python:3.12-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install uv

COPY agno-assistant /app/agno-assistant

WORKDIR /app/agno-assistant

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system -e .

FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

COPY --from=builder /app/agno-assistant /app/agno-assistant

RUN useradd -m -u 1000 appuser
USER appuser

EXPOSE 7777

ENTRYPOINT ["python", "-m", "agno_assistant.main"]
