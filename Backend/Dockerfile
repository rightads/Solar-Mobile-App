FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PORT=8000 \
    UPLOAD_DIR=/data/uploads

WORKDIR /app

# Build deps only for compiling wheels, removed in the same layer.
COPY requirements.txt ./
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential curl \
    && pip install -r requirements.txt \
    && apt-get purge -y build-essential \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Unprivileged runtime user; uploads live on a mounted volume outside the code.
RUN useradd -m -u 1000 appuser \
    && mkdir -p /data/uploads \
    && chown -R appuser:appuser /data
USER appuser

COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser gunicorn_conf.py ./

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -fsS http://127.0.0.1:${PORT}/api/v1/health || exit 1

CMD ["gunicorn", "app.main:app", "-c", "gunicorn_conf.py"]
