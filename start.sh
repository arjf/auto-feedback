#!/bin/bash

# Auto-Feedback Application Startup Script
# Simplified version - just start the services

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
FLASK_HOST=${FLASK_HOST:-"0.0.0.0"}
FLASK_PORT=${FLASK_PORT:-5000}
FLASK_DEBUG=${FLASK_DEBUG:-false}
STREAMLIT_HOST=${STREAMLIT_HOST:-"0.0.0.0"}
STREAMLIT_PORT=${STREAMLIT_PORT:-8501}
API_URL=${API_URL:-"http://localhost:${FLASK_PORT}"}

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1" >&2
}

# Cleanup function for graceful shutdown
cleanup() {
    log "Received shutdown signal, cleaning up..."

    if [ ! -z "${FLASK_PID:-}" ] && kill -0 "$FLASK_PID" 2>/dev/null; then
        log "Stopping Flask API (PID: $FLASK_PID)..."
        kill -TERM "$FLASK_PID" 2>/dev/null || true
        wait "$FLASK_PID" 2>/dev/null || true
    fi

    if [ ! -z "${STREAMLIT_PID:-}" ] && kill -0 "$STREAMLIT_PID" 2>/dev/null; then
        log "Stopping Streamlit Dashboard (PID: $STREAMLIT_PID)..."
        kill -TERM "$STREAMLIT_PID" 2>/dev/null || true
        wait "$STREAMLIT_PID" 2>/dev/null || true
    fi

    log_success "Cleanup completed"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Start Flask API
start_flask() {
    log "Starting Flask API on ${FLASK_HOST}:${FLASK_PORT}..."

    export FLASK_HOST FLASK_PORT FLASK_DEBUG

    cd /app
    python app/main.py &
    FLASK_PID=$!

    log_success "Flask API started with PID: $FLASK_PID"
}

# Start Streamlit Dashboard
start_streamlit() {
    log "Starting Streamlit Dashboard on ${STREAMLIT_HOST}:${STREAMLIT_PORT}..."

    export API_URL

    cd /app
    python -m streamlit run app/dashboard.py \
        --server.port="$STREAMLIT_PORT" \
        --server.address="$STREAMLIT_HOST" \
        --server.headless=true \
        --browser.serverAddress="$STREAMLIT_HOST" \
        --browser.gatherUsageStats=false \
        --logger.level=info \
        &
    STREAMLIT_PID=$!

    log_success "Streamlit Dashboard started with PID: $STREAMLIT_PID"
}

# Monitor services
monitor_services() {
    log "Services are running. Monitoring..."
    log_success "Flask API: http://localhost:${FLASK_PORT}"
    log_success "Streamlit Dashboard: http://localhost:${STREAMLIT_PORT}"
    log "Press Ctrl+C to stop all services"

    while true; do
        # Check if Flask is still running
        if [ ! -z "${FLASK_PID:-}" ] && ! kill -0 "$FLASK_PID" 2>/dev/null; then
            log_error "Flask API process died unexpectedly"
            cleanup
            exit 1
        fi

        # Check if Streamlit is still running
        if [ ! -z "${STREAMLIT_PID:-}" ] && ! kill -0 "$STREAMLIT_PID" 2>/dev/null; then
            log_error "Streamlit Dashboard process died unexpectedly"
            cleanup
            exit 1
        fi

        sleep 30
    done
}

# Main function
main() {
    log "========================================"
    log "   Auto-Feedback Application Startup   "
    log "========================================"
    log ""

    log "Configuration:"
    log "  Flask Host: $FLASK_HOST"
    log "  Flask Port: $FLASK_PORT"
    log "  Flask Debug: $FLASK_DEBUG"
    log "  Streamlit Host: $STREAMLIT_HOST"
    log "  Streamlit Port: $STREAMLIT_PORT"
    log "  API URL: $API_URL"
    log ""

    # Start services
    start_flask
    start_streamlit

    # Monitor services
    monitor_services
}

# Run main function
main "$@"
