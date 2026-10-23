# Stage 1: Builder
FROM python:3.12-slim AS builder

ENV POETRY_VERSION=1.8.3 \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1

RUN pip install --no-cache-dir "poetry==$POETRY_VERSION"

WORKDIR /app

COPY pyproject.toml poetry.lock ./
RUN poetry install --only main --no-root

COPY src/ ./src/
RUN poetry install --only main


# Stage 2: Runtime
FROM python:3.12-slim AS runtime

RUN groupadd --gid 1000 appgroup && \
    useradd --uid 1000 --gid 1000 --home-dir /app --shell /usr/sbin/nologin appuser

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/src /app/src

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONPATH="/app/src" \
    PYTHONUNBUFFERED=1

USER 1000:1000

EXPOSE 8080

CMD ["python", "-m", "audit_svc"]
