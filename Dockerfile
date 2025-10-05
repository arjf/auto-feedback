# Use Python 3.10 as base image
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Download NLTK data (required for TextBlob)
RUN python -m textblob.download_corpora

# Copy application code
COPY app/ ./app/

# Expose ports
# 5000 for Flask API
# 8501 for Streamlit Dashboard
EXPOSE 5000 8501

# Create a startup script
RUN echo '#!/bin/bash\n\
echo "Starting Flask API in background..."\n\
cd /app && python app/main.py &\n\
echo "Starting Streamlit Dashboard..."\n\
cd /app && streamlit run app/dashboard.py --server.port=8501 --server.address=0.0.0.0\n\
' > /app/start.sh && chmod +x /app/start.sh

# Default command runs Streamlit (can be overridden)
CMD ["streamlit", "run", "app/dashboard.py", "--server.port=8501", "--server.address=0.0.0.0"]

# Alternative: To run both Flask and Streamlit, use:
# CMD ["/app/start.sh"]
