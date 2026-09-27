FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PORT=8080

WORKDIR /app
COPY pyproject.toml README.md ./
COPY src ./src
RUN pip install . \
    && useradd --system --uid 1001 --no-create-home app

USER app
EXPOSE 8080
CMD ["sh", "-c", "exec uvicorn outing_agent.api.app:app --host 0.0.0.0 --port ${PORT}"]
