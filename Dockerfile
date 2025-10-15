# Multi-stage build for better optimization
FROM python:3.10-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
  PYTHONDONTWRITEBYTECODE=1 \
  PIP_NO_CACHE_DIR=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
  gcc \
  g++ \
  curl \
  supervisor \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash app \
  && mkdir -p /app /var/log/supervisor \
  && chown -R app:app /app /var/log/supervisor

# Set working directory
WORKDIR /app

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Download NLTK data (required for TextBlob)
RUN python -m textblob.download_corpora

# Copy application code
COPY app/ ./app/
COPY start.sh ./

# Create supervisord configuration
RUN mkdir -p /etc/supervisor/conf.d
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make scripts executable
RUN chmod +x start.sh

# Change ownership to app user
RUN chown -R app:app /app

# Configuration via environment variables
ENV FLASK_HOST=0.0.0.0 \
  FLASK_PORT=5000 \
  FLASK_DEBUG=false \
  STREAMLIT_HOST=0.0.0.0 \
  STREAMLIT_PORT=8501 \
  API_URL=http://localhost:5000

# Expose ports
EXPOSE $FLASK_PORT $STREAMLIT_PORT

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:$FLASK_PORT/health && \
  curl -f http://localhost:$STREAMLIT_PORT/_stcore/health || exit 1

# Switch to non-root user
USER app

# Use supervisord to manage multiple processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
