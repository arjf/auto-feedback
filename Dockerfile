FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1 \
  PYTHONDONTWRITEBYTECODE=1 \
  PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y \
  gcc \
  g++ \
  curl \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean

RUN useradd --create-home --shell /bin/bash app \
  && mkdir -p /app \
  && chown -R app:app /app

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN python -m textblob.download_corpora

COPY app/ ./app/
COPY start.sh ./
RUN chmod +x start.sh
RUN chown -R app:app /app

ENV FLASK_HOST=0.0.0.0 \
  FLASK_PORT=5000 \
  FLASK_DEBUG=false \
  STREAMLIT_HOST=0.0.0.0 \
  STREAMLIT_PORT=8501 \
  API_URL=http://localhost:5000

EXPOSE 5000 8501

USER app

CMD ["./start.sh"]
