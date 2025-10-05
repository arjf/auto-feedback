#!/bin/bash
# Startup script for Sentiment Analysis App on macOS/Linux
# This script starts both Flask API and Streamlit Dashboard

echo "========================================"
echo " Sentiment Analysis App Startup"
echo "========================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.10 or higher"
    exit 1
fi

echo "[1/4] Checking Python installation..."
python3 --version

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo ""
    echo "[2/4] Creating virtual environment..."
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create virtual environment"
        exit 1
    fi
else
    echo ""
    echo "[2/4] Virtual environment already exists"
fi

# Activate virtual environment
echo ""
echo "[3/4] Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo ""
echo "[4/4] Installing dependencies (this may take a while)..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install dependencies"
    exit 1
fi

# Download NLTK data for TextBlob
echo ""
echo "Downloading NLTK data..."
python -m textblob.download_corpora

echo ""
echo "========================================"
echo " Installation Complete!"
echo "========================================"
echo ""
echo "Starting Flask API and Streamlit Dashboard..."
echo ""
echo "Flask API will run on: http://localhost:5000"
echo "Streamlit Dashboard will run on: http://localhost:8501"
echo ""
echo "Press Ctrl+C in each terminal to stop the servers"
echo ""
echo "========================================"
echo ""

# Start Flask API in background
echo "Starting Flask API..."
python app/main.py &
FLASK_PID=$!

# Wait a moment for Flask to start
sleep 3

# Start Streamlit Dashboard
echo "Starting Streamlit Dashboard..."
streamlit run app/dashboard.py

# Clean up: Kill Flask when Streamlit exits
echo ""
echo "Stopping Flask API..."
kill $FLASK_PID 2>/dev/null

echo "All services stopped."
