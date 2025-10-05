@echo off
REM Startup script for Sentiment Analysis App on Windows
REM This script starts both Flask API and Streamlit Dashboard

echo ========================================
echo  Sentiment Analysis App Startup
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.10 or higher
    pause
    exit /b 1
)

echo [1/4] Checking Python installation...
python --version

REM Check if virtual environment exists
if not exist "venv\" (
    echo.
    echo [2/4] Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
) else (
    echo.
    echo [2/4] Virtual environment already exists
)

REM Activate virtual environment
echo.
echo [3/4] Activating virtual environment...
call venv\Scripts\activate.bat

REM Install dependencies
echo.
echo [4/4] Installing dependencies (this may take a while)...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

REM Download NLTK data for TextBlob
echo.
echo Downloading NLTK data...
python -m textblob.download_corpora

echo.
echo ========================================
echo  Installation Complete!
echo ========================================
echo.
echo Starting Flask API and Streamlit Dashboard...
echo.
echo Flask API will run on: http://localhost:5000
echo Streamlit Dashboard will run on: http://localhost:8501
echo.
echo Press Ctrl+C to stop both servers
echo.
echo ========================================
echo.

REM Start Flask API in background
start "Flask API" cmd /k "venv\Scripts\activate.bat && python app\main.py"

REM Wait a moment for Flask to start
timeout /t 3 /nobreak >nul

REM Start Streamlit Dashboard
echo Starting Streamlit Dashboard...
streamlit run app\dashboard.py

REM This will only execute if Streamlit is closed
echo.
echo Streamlit closed. Flask API is still running in separate window.
echo Close the Flask API window manually if needed.
pause
