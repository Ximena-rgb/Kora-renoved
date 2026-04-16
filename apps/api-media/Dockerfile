FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# Instalamos sin nudenet por defecto para no bloquear el arranque.
# nudenet descarga modelos pesados; se activa añadiendo ENABLE_NSFW=true
RUN pip install --no-cache-dir django==5.0.4 python-decouple==3.8 \
    redis==5.0.4 Pillow==10.3.0 prometheus-client==0.20.0 requests==2.32.3 \
    python-json-logger==2.0.7

COPY src/ .

RUN mkdir -p /storage/uploads/profiles/original \
             /storage/uploads/profiles/medium \
             /storage/uploads/profiles/thumb \
             /storage/uploads/plans/original \
             /storage/uploads/plans/medium \
             /storage/uploads/plans/thumb

CMD ["python", "worker.py"]
