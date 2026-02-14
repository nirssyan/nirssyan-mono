# Build stage
FROM python:3.12-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast dependency resolution
RUN pip install uv

# Copy shared-python first (it's a local dependency)
COPY shared-python /app/shared-python

# Copy agents
COPY agents /app/agents

WORKDIR /app/agents

# Create modified pyproject.toml with correct path for Docker context
RUN sed -i 's|file://../shared-python|file:///app/shared-python|g' pyproject.toml

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system /app/shared-python && \
    uv pip install --system -e .

# Final stage
FROM python:3.12-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY --from=builder /app/agents /app/agents
COPY --from=builder /app/shared-python /app/shared-python

# Create non-root user
RUN useradd -m -u 1000 appuser
USER appuser

# Expose metrics port
EXPOSE 9464

ENTRYPOINT ["python", "-m", "agents.main"]
