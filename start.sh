#!/bin/bash

# Auto-Feedback Application Startup Script
# Enhanced version with error handling and environment variable support

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration (can be overridden by environment variables)
FLASK_HOST=${FLASK_HOST:-"0.0.0.0"}
FLASK_PORT=${FLASK_PORT:-5000}
FLASK_DEBUG=${FLASK_DEBUG:-false}
STREAMLIT_HOST=${STREAMLIT_HOST:-"0.0.0.0"}
STREAMLIT_PORT=${STREAMLIT_PORT:-8501}
API_URL=${API_URL:-"http://localhost:${FLASK_PORT}"}
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-30}
MAX_STARTUP_WAIT=${MAX_STARTUP_WAIT:-60}

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

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
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

# Check if Python is available
check_python() {
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        log_error "Python is not installed or not in PATH"
        exit 1
    fi

    local python_cmd="python3"
    if ! command -v python3 &> /dev/null; then
        python_cmd="python"
    fi

    log_success "Python found: $($python_cmd --version)"
    echo "$python_cmd"
}

# Check if required dependencies are installed
check_dependencies() {
    local python_cmd="$1"

    log "Checking required dependencies..."

    local missing_deps=()

    if ! $python_cmd -c "import flask" 2>/dev/null; then
        missing_deps+=("flask")
    fi

    if ! $python_cmd -c "import streamlit" 2>/dev/null; then
        missing_deps+=("streamlit")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log "Please install dependencies with: pip install -r requirements.txt"
        exit 1
    fi

    log_success "All dependencies are installed"
}

# Health check function
health_check() {
    local service_name="$1"
    local url="$2"
    local max_attempts=10
    local attempt=1

    log "Performing health check for $service_name..."

    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            log_success "$service_name is healthy"
            return 0
        fi

        log "Health check attempt $attempt/$max_attempts failed for $service_name"
        sleep 3
        ((attempt++))
    done

    log_error "$service_name health check failed after $max_attempts attempts"
    return 1
}

# Start Flask API
start_flask() {
    local python_cmd="$1"

    log "Starting Flask API on ${FLASK_HOST}:${FLASK_PORT}..."

    # Set environment variables for Flask
    export FLASK_HOST FLASK_PORT FLASK_DEBUG

    cd /app
    $python_cmd app/main.py &
    FLASK_PID=$!

    log "Flask API started with PID: $FLASK_PID"

    # Wait a moment and check if process is still running
    sleep 2
    if ! kill -0 "$FLASK_PID" 2>/dev/null; then
        log_error "Flask API failed to start"
        exit 1
    fi

    # Perform health check
    if ! health_check "Flask API" "http://localhost:${FLASK_PORT}/health"; then
        log_error "Flask API health check failed"
        cleanup
        exit 1
    fi
}

# Start Streamlit Dashboard
start_streamlit() {
    local python_cmd="$1"

    log "Starting Streamlit Dashboard on ${STREAMLIT_HOST}:${STREAMLIT_PORT}..."

    # Set environment variables for Streamlit
    export API_URL

    cd /app
    $python_cmd -m streamlit run app/dashboard.py \
        --server.port="$STREAMLIT_PORT" \
        --server.address="$STREAMLIT_HOST" \
        --server.headless=true \
        --browser.serverAddress="$STREAMLIT_HOST" \
        --browser.gatherUsageStats=false \
        --logger.level=info \
        &
    STREAMLIT_PID=$!

    log "Streamlit Dashboard started with PID: $STREAMLIT_PID"

    # Wait a moment and check if process is still running
    sleep 3
    if ! kill -0 "$STREAMLIT_PID" 2>/dev/null; then
        log_error "Streamlit Dashboard failed to start"
        cleanup
        exit 1
    fi

    # Perform health check (Streamlit doesn't have a traditional health endpoint)
    # We'll just check if the port is accepting connections
    local streamlit_health_url="http://localhost:${STREAMLIT_PORT}/_stcore/health"
    if ! health_check "Streamlit Dashboard" "$streamlit_health_url"; then
        log_warning "Streamlit health check failed, but service might still be starting..."
        # Give it more time as Streamlit can be slow to start
        sleep 5
    fi
}

# Monitor services
monitor_services() {
    log "Starting service monitoring..."
    log_success "Services are running. Monitoring for failures..."
    log "Flask API: http://localhost:${FLASK_PORT}"
    log "Streamlit Dashboard: http://localhost:${STREAMLIT_PORT}"
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

        # Periodic health checks
        if ! curl -f -s "http://localhost:${FLASK_PORT}/health" > /dev/null 2>&1; then
            log_warning "Flask API health check failed"
        fi

        sleep "$HEALTH_CHECK_INTERVAL"
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

    # Check Python installation
    python_cmd=$(check_python)

    # Check dependencies
    check_dependencies "$python_cmd"

    # Start services
    start_flask "$python_cmd"
    start_streamlit "$python_cmd"

    # Monitor services
    monitor_services
}

# Run main function
main "$@"
