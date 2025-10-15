#!/bin/bash

# User Data Script for Auto-Feedback Application EC2 Instances
# This script initializes the instance with all necessary software and configurations

set -e  # Exit on any error
set -x  # Enable debug logging

# Script metadata
SCRIPT_VERSION="2.0.0"
LOG_FILE="/var/log/user-data.log"
CONTAINER_IMAGE="${container_image}"
ENVIRONMENT="${environment}"
DEPLOYMENT_ID="${deployment_id}"
S3_BUCKET="${bucket_name}"
AWS_REGION="${region}"

# Redirect all output to log file and console
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=========================================="
echo "Auto-Feedback EC2 Instance Initialization"
echo "Version: $SCRIPT_VERSION"
echo "Started at: $(date)"
echo "=========================================="

echo "Configuration:"
echo "  Container Image: $CONTAINER_IMAGE"
echo "  Environment: $ENVIRONMENT"
echo "  Deployment ID: $DEPLOYMENT_ID"
echo "  S3 Bucket: $S3_BUCKET"
echo "  AWS Region: $AWS_REGION"

# Update system packages
echo "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install essential packages
echo "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    unzip \
    jq \
    htop \
    tree \
    vim \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    awscli \
    python3 \
    python3-pip \
    supervisor \
    nginx \
    fail2ban \
    ufw \
    logrotate

# Configure timezone
echo "Configuring timezone..."
timedatectl set-timezone UTC

# Create application user
echo "Creating application user..."
useradd -m -s /bin/bash appuser
usermod -aG sudo appuser
usermod -aG docker appuser || true  # docker group may not exist yet

# Set up SSH keys from GitHub
echo "Setting up SSH keys..."
if [ -n "${github_ssh_keys}" ]; then
    # Set up keys for root user
    mkdir -p /root/.ssh
    echo "${github_ssh_keys}" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chmod 700 /root/.ssh

    # Set up keys for ubuntu user
    mkdir -p /home/ubuntu/.ssh
    echo "${github_ssh_keys}" > /home/ubuntu/.ssh/authorized_keys
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    chmod 600 /home/ubuntu/.ssh/authorized_keys
    chmod 700 /home/ubuntu/.ssh

    # Set up keys for appuser
    mkdir -p /home/appuser/.ssh
    echo "${github_ssh_keys}" > /home/appuser/.ssh/authorized_keys
    chown -R appuser:appuser /home/appuser/.ssh
    chmod 600 /home/appuser/.ssh/authorized_keys
    chmod 700 /home/appuser/.ssh

    echo "SSH keys configured for root, ubuntu, and appuser"
else
    echo "Warning: No GitHub SSH keys provided"
fi

# Configure SSH security
echo "Configuring SSH security..."
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add users to docker group
usermod -aG docker ubuntu
usermod -aG docker appuser

# Install Docker Compose (standalone)
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.21.0"
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install CloudWatch Agent
echo "Installing CloudWatch Agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f ./amazon-cloudwatch-agent.deb

# Configure CloudWatch Agent
echo "Configuring CloudWatch Agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "AutoFeedback/EC2",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time",
                    "read_bytes",
                    "write_bytes",
                    "reads",
                    "writes"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/user-data.log",
                        "log_group_name": "/aws/ec2/auto-feedback",
                        "log_stream_name": "{instance_id}/user-data"
                    },
                    {
                        "file_path": "/var/log/docker.log",
                        "log_group_name": "/aws/ec2/auto-feedback",
                        "log_stream_name": "{instance_id}/docker"
                    },
                    {
                        "file_path": "/var/log/application.log",
                        "log_group_name": "/aws/ec2/auto-feedback",
                        "log_stream_name": "{instance_id}/application"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Configure firewall
echo "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow ssh

# Allow application ports
ufw allow 5000/tcp comment 'Flask API'
ufw allow 8501/tcp comment 'Streamlit Dashboard'

# Allow HTTP/HTTPS for health checks and load balancer
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Enable firewall
ufw --force enable

# Configure fail2ban
echo "Configuring fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i 's/bantime  = 10m/bantime  = 1h/' /etc/fail2ban/jail.local
sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban

# Create application directories
echo "Creating application directories..."
mkdir -p /opt/auto-feedback
mkdir -p /opt/auto-feedback/data
mkdir -p /opt/auto-feedback/logs
mkdir -p /opt/auto-feedback/config
mkdir -p /var/log/auto-feedback

# Set permissions
chown -R appuser:appuser /opt/auto-feedback
chown -R appuser:appuser /var/log/auto-feedback

# Create application configuration
echo "Creating application configuration..."
cat > /opt/auto-feedback/config/app.env << EOF
# Application Configuration
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
FLASK_DEBUG=false
STREAMLIT_HOST=0.0.0.0
STREAMLIT_PORT=8501
API_URL=http://localhost:5000
PYTHONUNBUFFERED=1
PYTHONDONTWRITEBYTECODE=1

# Environment specific
ENVIRONMENT=$ENVIRONMENT
DEPLOYMENT_ID=$DEPLOYMENT_ID
AWS_REGION=$AWS_REGION
S3_BUCKET=$S3_BUCKET

# Logging
LOG_LEVEL=INFO
LOG_FILE=/var/log/auto-feedback/application.log

# Resource limits
MEMORY_LIMIT=1g
CPU_LIMIT=1.0
EOF

# Create Docker Compose configuration
echo "Creating Docker Compose configuration..."
cat > /opt/auto-feedback/docker-compose.yml << EOF
version: '3.8'

services:
  auto-feedback:
    image: $CONTAINER_IMAGE
    container_name: auto-feedback-app
    restart: unless-stopped

    ports:
      - "5000:5000"
      - "8501:8501"

    env_file:
      - ./config/app.env

    volumes:
      - ./data:/app/data
      - ./logs:/var/log/supervisor
      - /var/log/auto-feedback:/app/logs

    healthcheck:
      test: |
        curl -f http://localhost:5000/health &&
        curl -f http://localhost:8501/_stcore/health
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 512M

networks:
  default:
    name: auto-feedback-network
EOF

# Create systemd service for the application
echo "Creating systemd service..."
cat > /etc/systemd/system/auto-feedback.service << EOF
[Unit]
Description=Auto-Feedback Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/auto-feedback
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=300
User=appuser
Group=appuser

[Install]
WantedBy=multi-user.target
EOF

# Create health check script
echo "Creating health check script..."
cat > /opt/auto-feedback/health-check.sh << 'EOF'
#!/bin/bash

# Health check script for Auto-Feedback application
# This script checks if both Flask API and Streamlit are running properly

FLASK_URL="http://localhost:5000/health"
STREAMLIT_URL="http://localhost:8501"
LOG_FILE="/var/log/auto-feedback/health-check.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check Flask API
if curl -f -s --max-time 10 "$FLASK_URL" > /dev/null; then
    log_message "Flask API health check: PASSED"
    flask_status=0
else
    log_message "Flask API health check: FAILED"
    flask_status=1
fi

# Check Streamlit (basic connectivity)
if curl -f -s --max-time 10 "$STREAMLIT_URL" > /dev/null; then
    log_message "Streamlit health check: PASSED"
    streamlit_status=0
else
    log_message "Streamlit health check: FAILED"
    streamlit_status=1
fi

# Overall health status
if [ $flask_status -eq 0 ] && [ $streamlit_status -eq 0 ]; then
    log_message "Overall health check: HEALTHY"
    exit 0
else
    log_message "Overall health check: UNHEALTHY"
    exit 1
fi
EOF

chmod +x /opt/auto-feedback/health-check.sh
chown appuser:appuser /opt/auto-feedback/health-check.sh

# Set up cron job for health checks
echo "Setting up health check cron job..."
echo "*/5 * * * * appuser /opt/auto-feedback/health-check.sh" >> /etc/crontab

# Configure log rotation
echo "Configuring log rotation..."
cat > /etc/logrotate.d/auto-feedback << EOF
/var/log/auto-feedback/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    postrotate
        # Restart application if needed
        systemctl restart auto-feedback || true
    endscript
}
EOF

# Pull the container image
echo "Pulling container image: $CONTAINER_IMAGE"
docker pull "$CONTAINER_IMAGE" || {
    echo "Warning: Failed to pull container image. Will retry during service start."
}

# Start and enable the application service
echo "Starting Auto-Feedback application..."
systemctl daemon-reload
systemctl enable auto-feedback
systemctl start auto-feedback

# Wait for application to start
echo "Waiting for application to start..."
sleep 30

# Verify the application is running
echo "Verifying application health..."
max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    if /opt/auto-feedback/health-check.sh; then
        echo "Application health check passed!"
        break
    else
        echo "Health check attempt $attempt/$max_attempts failed, retrying..."
        sleep 15
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "Warning: Application health checks failed after $max_attempts attempts"
    echo "Check logs: docker-compose -f /opt/auto-feedback/docker-compose.yml logs"
else
    echo "Application started successfully!"
fi

# Configure nginx as reverse proxy (optional)
echo "Configuring nginx reverse proxy..."
cat > /etc/nginx/sites-available/auto-feedback << EOF
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # API endpoints
    location /api/ {
        proxy_pass http://localhost:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Health check
        location /api/health {
            proxy_pass http://localhost:5000/health;
            access_log off;
        }
    }

    # Dashboard
    location / {
        proxy_pass http://localhost:8501/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support for Streamlit
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Health check endpoint for load balancer
    location /health {
        proxy_pass http://localhost:5000/health;
        access_log off;
    }
}
EOF

# Enable the nginx site
ln -sf /etc/nginx/sites-available/auto-feedback /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload nginx
nginx -t && systemctl reload nginx || echo "Nginx configuration failed"

# Install and configure CloudWatch monitoring
echo "Setting up CloudWatch custom metrics..."
cat > /opt/auto-feedback/send-metrics.sh << 'EOF'
#!/bin/bash

# Send custom metrics to CloudWatch
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Check if application is healthy
if /opt/auto-feedback/health-check.sh > /dev/null 2>&1; then
    HEALTH_STATUS=1
else
    HEALTH_STATUS=0
fi

# Send health status metric
aws cloudwatch put-metric-data \
    --namespace "AutoFeedback/Application" \
    --metric-data MetricName=HealthStatus,Value=$HEALTH_STATUS,Unit=None,Dimensions=InstanceId=$INSTANCE_ID \
    --region $REGION

# Send container status metric
CONTAINER_COUNT=$(docker ps --filter "name=auto-feedback-app" --filter "status=running" -q | wc -l)
aws cloudwatch put-metric-data \
    --namespace "AutoFeedback/Application" \
    --metric-data MetricName=RunningContainers,Value=$CONTAINER_COUNT,Unit=Count,Dimensions=InstanceId=$INSTANCE_ID \
    --region $REGION
EOF

chmod +x /opt/auto-feedback/send-metrics.sh
chown appuser:appuser /opt/auto-feedback/send-metrics.sh

# Add metrics to cron
echo "*/5 * * * * appuser /opt/auto-feedback/send-metrics.sh > /dev/null 2>&1" >> /etc/crontab

# Create instance metadata file
echo "Creating instance metadata..."
cat > /opt/auto-feedback/instance-metadata.json << EOF
{
    "instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
    "instance_type": "$(curl -s http://169.254.169.254/latest/meta-data/instance-type)",
    "availability_zone": "$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)",
    "public_ipv4": "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)",
    "local_ipv4": "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)",
    "container_image": "$CONTAINER_IMAGE",
    "environment": "$ENVIRONMENT",
    "deployment_id": "$DEPLOYMENT_ID",
    "initialized_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "script_version": "$SCRIPT_VERSION"
}
EOF

chown appuser:appuser /opt/auto-feedback/instance-metadata.json

# Final system cleanup
echo "Performing final cleanup..."
apt-get autoremove -y
apt-get autoclean
docker system prune -f

# Send initialization complete signal to CloudWatch
echo "Sending initialization complete signal..."
aws cloudwatch put-metric-data \
    --namespace "AutoFeedback/Initialization" \
    --metric-data MetricName=InitializationComplete,Value=1,Unit=None,Dimensions=InstanceId=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
    --region $AWS_REGION || echo "Failed to send initialization metric"

echo "=========================================="
echo "Instance initialization completed successfully!"
echo "Completed at: $(date)"
echo "=========================================="
echo ""
echo "Application Status:"
echo "  Flask API: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000"
echo "  Streamlit Dashboard: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8501"
echo "  Health Check: /opt/auto-feedback/health-check.sh"
echo "  Logs: /var/log/auto-feedback/"
echo "  Configuration: /opt/auto-feedback/config/"
echo ""
echo "Useful Commands:"
echo "  docker-compose -f /opt/auto-feedback/docker-compose.yml logs -f"
echo "  systemctl status auto-feedback"
echo "  /opt/auto-feedback/health-check.sh"
echo ""

# Log the completion
echo "User data script completed successfully at $(date)" >> /var/log/user-data.log

# Exit successfully
exit 0
