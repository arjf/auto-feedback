#!/bin/bash

# Enhanced Deployment Script for Auto-Feedback Application
# This script handles infrastructure provisioning and application deployment
# with comprehensive error handling, security, and monitoring

set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit if any command in a pipeline fails

# Script metadata
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="deploy.sh"
START_TIME=$(date +%s)

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Default configuration (can be overridden by environment variables)
AWS_REGION=${AWS_REGION:-"us-east-1"}
ENVIRONMENT=${ENVIRONMENT:-"staging"}
DEPLOYMENT_ID=${DEPLOYMENT_ID:-"deploy-$(date +%Y%m%d-%H%M%S)"}
TERRAFORM_VERSION=${TERRAFORM_VERSION:-"1.6.0"}
ANSIBLE_VERSION=${ANSIBLE_VERSION:-"8.0.0"}
CONTAINER_IMAGE=${CONTAINER_IMAGE:-"ghcr.io/kaushik1919/auto-feedback:latest"}
MAX_DEPLOYMENT_TIME=${MAX_DEPLOYMENT_TIME:-1800}  # 30 minutes
HEALTH_CHECK_TIMEOUT=${HEALTH_CHECK_TIMEOUT:-300} # 5 minutes
BACKUP_ENABLED=${BACKUP_ENABLED:-"true"}
ROLLBACK_ON_FAILURE=${ROLLBACK_ON_FAILURE:-"true"}
NOTIFICATION_ENABLED=${NOTIFICATION_ENABLED:-"false"}
LOG_LEVEL=${LOG_LEVEL:-"INFO"}

# Derived variables
LOG_FILE="/tmp/${SCRIPT_NAME}-${DEPLOYMENT_ID}.log"
SSH_KEY_FILE="/tmp/deployment_ssh_key_${DEPLOYMENT_ID}"
TERRAFORM_DIR="terraform"
ANSIBLE_DIR="ansible"
BACKUP_DIR="/tmp/deployment_backup_${DEPLOYMENT_ID}"

# Global variables for cleanup
INSTANCE_IPS=""
PREVIOUS_DEPLOYMENT=""
DEPLOYMENT_STATUS="unknown"
CLEANUP_REQUIRED="false"

# Logging functions
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""

    case "$level" in
        "ERROR")   color=$RED ;;
        "WARN")    color=$YELLOW ;;
        "INFO")    color=$BLUE ;;
        "SUCCESS") color=$GREEN ;;
        "DEBUG")   color=$PURPLE ;;
        *)         color=$NC ;;
    esac

    # Log to file
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"

    # Log to console with colors
    echo -e "${color}[${timestamp}] [${level}]${NC} ${message}"
}

log_error() {
    log "ERROR" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_info() {
    log "INFO" "$@"
}

log_success() {
    log "SUCCESS" "$@"
}

log_debug() {
    if [ "$LOG_LEVEL" = "DEBUG" ]; then
        log "DEBUG" "$@"
    fi
}

# Error handling and cleanup
cleanup_on_exit() {
    local exit_code=$?

    log_info "Performing cleanup operations..."
    CLEANUP_REQUIRED="true"

    # Remove temporary SSH key
    if [ -f "$SSH_KEY_FILE" ]; then
        rm -f "$SSH_KEY_FILE"
        log_debug "Removed temporary SSH key file"
    fi

    # Clean up temporary directories
    if [ -d "$BACKUP_DIR" ]; then
        rm -rf "$BACKUP_DIR"
        log_debug "Removed backup directory"
    fi

    # Calculate deployment duration
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    if [ $exit_code -eq 0 ]; then
        log_success "Deployment completed successfully in ${duration}s"
        DEPLOYMENT_STATUS="success"
    else
        log_error "Deployment failed after ${duration}s with exit code $exit_code"
        DEPLOYMENT_STATUS="failed"

        # Trigger rollback if enabled and we have backup info
        if [ "$ROLLBACK_ON_FAILURE" = "true" ] && [ -n "$PREVIOUS_DEPLOYMENT" ]; then
            log_warn "Initiating automatic rollback..."
            perform_rollback || log_error "Rollback failed - manual intervention required"
        fi
    fi

    # Send notification if enabled
    if [ "$NOTIFICATION_ENABLED" = "true" ]; then
        send_notification "$DEPLOYMENT_STATUS" "$duration"
    fi

    # Archive logs
    if [ -f "$LOG_FILE" ]; then
        log_info "Deployment log archived at: $LOG_FILE"
    fi

    exit $exit_code
}

# Set up signal handlers
trap 'log_error "Deployment interrupted by user"; cleanup_on_exit' INT TERM
trap 'cleanup_on_exit' EXIT

# Validation functions
validate_environment() {
    log_info "Validating deployment environment..."

    # Check required environment variables
    local required_vars=(
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "SSH_PRIVATE_KEY"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
            return 1
        fi
    done

    # Validate AWS credentials
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        log_error "AWS credentials are invalid or not configured"
        return 1
    fi

    log_debug "AWS credentials validated"

    # Validate SSH key
    if ! echo "$SSH_PRIVATE_KEY" | ssh-keygen -l -f - > /dev/null 2>&1; then
        log_error "SSH private key is invalid"
        return 1
    fi

    log_debug "SSH key validated"

    # Check if container image exists
    if ! docker manifest inspect "$CONTAINER_IMAGE" > /dev/null 2>&1; then
        log_warn "Container image $CONTAINER_IMAGE may not exist or is not accessible"
    fi

    # Validate environment name
    if [[ ! "$ENVIRONMENT" =~ ^(staging|production|development)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be staging, production, or development"
        return 1
    fi

    log_success "Environment validation completed"
    return 0
}

validate_tools() {
    log_info "Validating required tools..."

    local required_tools=("aws" "terraform" "ansible" "jq" "curl" "docker")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        return 1
    fi

    # Check versions
    log_debug "Tool versions:"
    log_debug "  AWS CLI: $(aws --version 2>&1 | head -n1)"
    log_debug "  Terraform: $(terraform version -json | jq -r '.terraform_version')"
    log_debug "  Ansible: $(ansible --version | head -n1)"
    log_debug "  Docker: $(docker --version)"

    log_success "Tool validation completed"
    return 0
}

# Infrastructure functions
setup_ssh_key() {
    log_info "Setting up SSH key for deployment..."

    # Create temporary SSH key file
    echo "$SSH_PRIVATE_KEY" > "$SSH_KEY_FILE"
    chmod 600 "$SSH_KEY_FILE"

    # Validate SSH key format
    if ! ssh-keygen -l -f "$SSH_KEY_FILE" > /dev/null 2>&1; then
        log_error "Invalid SSH key format"
        return 1
    fi

    log_debug "SSH key file created at: $SSH_KEY_FILE"
    return 0
}

backup_current_deployment() {
    if [ "$BACKUP_ENABLED" != "true" ]; then
        log_info "Backup is disabled, skipping..."
        return 0
    fi

    log_info "Creating backup of current deployment..."

    mkdir -p "$BACKUP_DIR"

    # Backup Terraform state
    if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        cp "$TERRAFORM_DIR/terraform.tfstate" "$BACKUP_DIR/terraform.tfstate.backup"
        log_debug "Terraform state backed up"
    fi

    # Get current deployment info
    cd "$TERRAFORM_DIR"
    if terraform show -json > "$BACKUP_DIR/current_deployment.json" 2>/dev/null; then
        PREVIOUS_DEPLOYMENT=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
        log_debug "Current deployment info backed up"
    fi
    cd - > /dev/null

    # Create backup metadata
    cat > "$BACKUP_DIR/backup_metadata.json" << EOF
{
    "backup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "deployment_id": "$DEPLOYMENT_ID",
    "environment": "$ENVIRONMENT",
    "previous_image": "$(terraform output -raw current_image 2>/dev/null || echo 'unknown')",
    "backup_location": "$BACKUP_DIR"
}
EOF

    log_success "Backup created at: $BACKUP_DIR"
    return 0
}

provision_infrastructure() {
    log_info "Provisioning infrastructure with Terraform..."

    cd "$TERRAFORM_DIR"

    # Initialize Terraform
    log_debug "Initializing Terraform..."
    if ! terraform init -no-color > /dev/null; then
        log_error "Terraform initialization failed"
        return 1
    fi

    # Create environment-specific variables
    cat > "terraform.tfvars" << EOF
aws_region = "$AWS_REGION"
environment = "$ENVIRONMENT"
deployment_id = "$DEPLOYMENT_ID"
container_image = "$CONTAINER_IMAGE"
github_username = "$(echo $CONTAINER_IMAGE | cut -d'/' -f2 | cut -d':' -f1)"

# Environment-specific settings
$(if [ "$ENVIRONMENT" = "production" ]; then
cat << PROD_EOF
instance_type = "t3.medium"
instance_count = 2
enable_monitoring = true
backup_retention_days = 30
enable_ssl = true
multi_az = true
PROD_EOF
else
cat << STAGING_EOF
instance_type = "t3.small"
instance_count = 1
enable_monitoring = true
backup_retention_days = 7
enable_ssl = false
multi_az = false
STAGING_EOF
fi)

bucket_name = "auto-feedback-${ENVIRONMENT}-$(echo $DEPLOYMENT_ID | tr '[:upper:]' '[:lower:]')"
EOF

    # Plan deployment
    log_debug "Planning Terraform deployment..."
    if ! terraform plan -var-file=terraform.tfvars -out=tfplan -no-color; then
        log_error "Terraform planning failed"
        return 1
    fi

    # Apply deployment
    log_info "Applying Terraform changes..."
    if ! terraform apply -auto-approve tfplan -no-color; then
        log_error "Terraform apply failed"
        return 1
    fi

    # Get infrastructure outputs
    INSTANCE_IPS=$(terraform output -json instance_public_ips 2>/dev/null | jq -r '.[]' | tr '\n' ' ' || \
                   terraform output -raw instance_public_ip 2>/dev/null || "")

    if [ -z "$INSTANCE_IPS" ]; then
        log_error "Failed to get instance IP addresses from Terraform output"
        return 1
    fi

    log_success "Infrastructure provisioning completed"
    log_info "Instance IPs: $INSTANCE_IPS"

    cd - > /dev/null
    return 0
}

wait_for_instances() {
    log_info "Waiting for instances to be ready..."

    local max_wait_time=600  # 10 minutes
    local start_wait_time=$(date +%s)
    local all_ready=false

    while [ "$all_ready" != "true" ]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_wait_time))

        if [ $elapsed -gt $max_wait_time ]; then
            log_error "Timeout waiting for instances to be ready"
            return 1
        fi

        all_ready=true

        for ip in $INSTANCE_IPS; do
            log_debug "Checking instance readiness: $ip"

            # Check SSH connectivity
            if ! timeout 10 ssh -i "$SSH_KEY_FILE" -o StrictHostKeyChecking=no \
                -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null \
                ubuntu@"$ip" "echo 'SSH connection successful'" > /dev/null 2>&1; then
                log_debug "Instance $ip not ready yet"
                all_ready=false
                break
            fi
        done

        if [ "$all_ready" != "true" ]; then
            log_debug "Waiting for instances... (${elapsed}s elapsed)"
            sleep 15
        fi
    done

    log_success "All instances are ready for deployment"
    return 0
}

deploy_application() {
    log_info "Deploying application with Ansible..."

    cd "$ANSIBLE_DIR"

    # Create dynamic inventory
    cat > inventory << EOF
[${ENVIRONMENT}]
$(for ip in $INSTANCE_IPS; do
    echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY_FILE ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
done)

[${ENVIRONMENT}:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

    # Create environment-specific variables
    mkdir -p "group_vars"
    cat > "group_vars/${ENVIRONMENT}.yml" << EOF
---
# Deployment configuration
environment: $ENVIRONMENT
deployment_id: $DEPLOYMENT_ID
container_image: $CONTAINER_IMAGE

# Application settings
flask_host: 0.0.0.0
flask_port: 5000
streamlit_host: 0.0.0.0
streamlit_port: 8501
api_url: "http://localhost:5000"

# Environment-specific settings
$(if [ "$ENVIRONMENT" = "production" ]; then
cat << PROD_VARS
flask_debug: false
log_level: WARNING
memory_limit: "2g"
cpu_limit: "1.0"
enable_ssl: true
domain_name: "auto-feedback.example.com"
rate_limiting: true
enable_monitoring: true
PROD_VARS
else
cat << STAGING_VARS
flask_debug: false
log_level: INFO
memory_limit: "1g"
cpu_limit: "0.5"
enable_ssl: false
domain_name: "staging.auto-feedback.example.com"
rate_limiting: false
enable_monitoring: true
STAGING_VARS
fi)

# Security settings
enable_security_headers: true
cors_origins: "*"
max_request_size: "10MB"

# Backup and monitoring
backup_enabled: $BACKUP_ENABLED
metrics_enabled: true
health_check_enabled: true
EOF

    # Run Ansible playbook
    log_info "Executing Ansible playbook..."
    if ! ansible-playbook -i inventory playbook.yml \
        --limit "$ENVIRONMENT" \
        --extra-vars "@group_vars/${ENVIRONMENT}.yml" \
        --timeout 300 \
        --ssh-common-args='-o UserKnownHostsFile=/dev/null'; then
        log_error "Ansible deployment failed"
        return 1
    fi

    cd - > /dev/null
    log_success "Application deployment completed"
    return 0
}

perform_health_checks() {
    log_info "Performing comprehensive health checks..."

    local health_check_start=$(date +%s)
    local all_healthy=false

    while [ "$all_healthy" != "true" ]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - health_check_start))

        if [ $elapsed -gt $HEALTH_CHECK_TIMEOUT ]; then
            log_error "Health check timeout after ${HEALTH_CHECK_TIMEOUT}s"
            return 1
        fi

        all_healthy=true

        for ip in $INSTANCE_IPS; do
            log_debug "Checking health for instance: $ip"

            # Check Flask API health
            local api_url="http://$ip:5000/health"
            if ! curl -f -s --max-time 10 "$api_url" | jq -e '.status == "healthy"' > /dev/null 2>&1; then
                log_debug "Flask API health check failed for $ip"
                all_healthy=false
                continue
            fi

            # Check Streamlit dashboard
            local streamlit_url="http://$ip:8501"
            if ! curl -f -s --max-time 10 "$streamlit_url" > /dev/null 2>&1; then
                log_debug "Streamlit health check failed for $ip"
                all_healthy=false
                continue
            fi

            # Functional test
            local test_response=$(curl -s -X POST "$api_url/../analyze" \
                -H "Content-Type: application/json" \
                -d '{"text": "Health check test message", "model": "textblob"}' 2>/dev/null || echo "")

            if ! echo "$test_response" | jq -e '.sentiment' > /dev/null 2>&1; then
                log_debug "Functional test failed for $ip"
                all_healthy=false
                continue
            fi

            log_debug "All health checks passed for $ip"
        done

        if [ "$all_healthy" != "true" ]; then
            log_debug "Health checks in progress... (${elapsed}s elapsed)"
            sleep 15
        fi
    done

    # Performance benchmarking
    log_info "Running performance benchmarks..."
    for ip in $INSTANCE_IPS; do
        local start_time=$(date +%s%N)
        curl -f -s "http://$ip:5000/health" > /dev/null
        local end_time=$(date +%s%N)
        local response_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds

        log_info "Instance $ip response time: ${response_time}ms"

        if [ $response_time -gt 5000 ]; then  # 5 seconds
            log_warn "High response time detected for $ip: ${response_time}ms"
        fi
    done

    log_success "All health checks completed successfully"
    return 0
}

perform_rollback() {
    if [ -z "$PREVIOUS_DEPLOYMENT" ]; then
        log_error "No previous deployment information available for rollback"
        return 1
    fi

    log_warn "Performing rollback to previous deployment..."

    # Restore Terraform state
    if [ -f "$BACKUP_DIR/terraform.tfstate.backup" ]; then
        cp "$BACKUP_DIR/terraform.tfstate.backup" "$TERRAFORM_DIR/terraform.tfstate"
        log_debug "Terraform state restored from backup"
    fi

    cd "$TERRAFORM_DIR"

    # Apply previous state
    if terraform apply -auto-approve -no-color; then
        log_success "Infrastructure rollback completed"
    else
        log_error "Infrastructure rollback failed"
        return 1
    fi

    cd - > /dev/null

    # Wait for rolled back instances
    sleep 30

    # Basic health check on rolled back deployment
    if curl -f -s "http://$PREVIOUS_DEPLOYMENT:5000/health" > /dev/null 2>&1; then
        log_success "Rollback verification successful"
        return 0
    else
        log_error "Rollback verification failed"
        return 1
    fi
}

send_notification() {
    local status=$1
    local duration=$2

    if [ "$NOTIFICATION_ENABLED" != "true" ]; then
        return 0
    fi

    log_info "Sending deployment notification..."

    local message="Deployment $DEPLOYMENT_ID ($ENVIRONMENT) $status after ${duration}s"
    local color="#36a64f"  # green

    if [ "$status" = "failed" ]; then
        color="#ff0000"  # red
    fi

    # Example Slack notification (requires SLACK_WEBHOOK_URL)
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"Deployment Notification\",
                    \"text\": \"$message\",
                    \"fields\": [
                        {\"title\": \"Environment\", \"value\": \"$ENVIRONMENT\", \"short\": true},
                        {\"title\": \"Image\", \"value\": \"$CONTAINER_IMAGE\", \"short\": true},
                        {\"title\": \"Duration\", \"value\": \"${duration}s\", \"short\": true},
                        {\"title\": \"Instances\", \"value\": \"$INSTANCE_IPS\", \"short\": false}
                    ]
                }]
            }" \
            "$SLACK_WEBHOOK_URL" > /dev/null 2>&1 || log_debug "Slack notification failed"
    fi

    log_debug "Notification sent"
}

show_deployment_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    log_info ""
    log_info "=============================================="
    log_info "           DEPLOYMENT SUMMARY"
    log_info "=============================================="
    log_info "Deployment ID: $DEPLOYMENT_ID"
    log_info "Environment: $ENVIRONMENT"
    log_info "Container Image: $CONTAINER_IMAGE"
    log_info "AWS Region: $AWS_REGION"
    log_info "Duration: ${duration}s"
    log_info "Status: $DEPLOYMENT_STATUS"
    log_info ""

    if [ -n "$INSTANCE_IPS" ]; then
        log_info "Deployed Instances:"
        for ip in $INSTANCE_IPS; do
            log_info "  - $ip"
            log_info "    API: http://$ip:5000"
            log_info "    Dashboard: http://$ip:8501"
        done
    fi

    log_info ""
    log_info "Log File: $LOG_FILE"
    log_info "=============================================="
}

# Main deployment function
main() {
    log_info "=============================================="
    log_info "  Auto-Feedback Deployment Script v$SCRIPT_VERSION"
    log_info "=============================================="
    log_info "Starting deployment: $DEPLOYMENT_ID"
    log_info "Environment: $ENVIRONMENT"
    log_info "Container Image: $CONTAINER_IMAGE"
    log_info "Log Level: $LOG_LEVEL"
    log_info ""

    # Pre-deployment validation
    validate_environment || {
        log_error "Environment validation failed"
        return 1
    }

    validate_tools || {
        log_error "Tool validation failed"
        return 1
    }

    setup_ssh_key || {
        log_error "SSH key setup failed"
        return 1
    }

    # Backup current deployment
    backup_current_deployment || {
        log_error "Backup creation failed"
        return 1
    }

    # Infrastructure provisioning
    provision_infrastructure || {
        log_error "Infrastructure provisioning failed"
        return 1
    }

    # Wait for instances to be ready
    wait_for_instances || {
        log_error "Instances failed to become ready"
        return 1
    }

    # Application deployment
    deploy_application || {
        log_error "Application deployment failed"
        return 1
    }

    # Health checks
    perform_health_checks || {
        log_error "Health checks failed"
        return 1
    }

    # Show summary
    show_deployment_summary

    log_success "Deployment completed successfully!"
    return 0
}

# Execute main function
main "$@"
