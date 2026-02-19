FROM python:3.12-slim AS builder

WORKDIR /app

RUN pip install uv

COPY agno-assistant/pyproject.toml /app/agno-assistant/pyproject.toml
COPY agno-assistant/agno_assistant /app/agno-assistant/agno_assistant

WORKDIR /app/agno-assistant

RUN uv pip install --system .

FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

RUN useradd -m -u 1000 appuser
USER appuser

EXPOSE 7777

CMD ["uvicorn", "agno_assistant.main:app", "--host", "0.0.0.0", "--port", "7777"]
