FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

# Dependencias del sistema:
# - libgl1, libglib2.0-0: OpenCV
# - libgomp1: DeepFace / TensorFlow
# - libpq-dev gcc: compilación de extensiones Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc libgl1 libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ .

RUN mkdir -p /storage/uploads/profiles/original \
             /storage/uploads/profiles/medium \
             /storage/uploads/profiles/thumb \
             /storage/uploads/plans/original \
             /storage/uploads/plans/medium \
             /storage/uploads/plans/thumb

CMD ["python", "worker.py"]
