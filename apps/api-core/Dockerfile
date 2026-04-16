FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    DJANGO_SETTINGS_MODULE=config.settings

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc curl postgresql-client redis-tools \
    ntpsec-ntpdate \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ .

RUN chmod +x entrypoint.sh && \
    mkdir -p /storage/uploads/profiles /storage/uploads/plans /storage/logs

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
