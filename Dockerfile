# Apache Superset with DataForge's configuration, theme and single sign-on.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 SUPERSET_HOME=/app/superset_home SUPERSET_CONFIG_PATH=/app/superset_config.py

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /usr/local/bin/uv

WORKDIR /app
COPY requirements.txt constraints-6.1.0.txt ./
RUN uv pip install --system --no-cache -r requirements.txt -c constraints-6.1.0.txt gunicorn gevent

COPY superset_config.py bootstrap.py run.py ./
COPY dataforge_superset ./dataforge_superset

RUN useradd --create-home --uid 10002 superset && mkdir -p /app/superset_home && chown -R superset /app/superset_home
USER superset

EXPOSE 8088
# PORT is set by the host (Render sets it); each gunicorn worker holds about 400 MB, so 2 fit in 2 GB.
CMD ["sh", "-c", "python bootstrap.py && exec gunicorn -w ${GUNICORN_WORKERS:-2} -k gevent --timeout 120 -b 0.0.0.0:${PORT:-8088} 'superset.app:create_app()'"]
