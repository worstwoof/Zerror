FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY backend/requirements.txt /tmp/backend-requirements.txt
COPY ai_engine/requirements.txt /tmp/ai-engine-requirements.txt

RUN pip install --upgrade pip \
    && pip install -r /tmp/backend-requirements.txt -r /tmp/ai-engine-requirements.txt

COPY backend /app/backend
COPY ai_engine /app/ai_engine

EXPOSE 8000

CMD ["uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
