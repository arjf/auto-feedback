# Auto-Feedback Application Terraform Configuration
# This file defines the infrastructure resources for deploying the application

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }

  # Backend configuration for state management
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "auto-feedback/terraform.tfstate"
  #   region = "us-east-1"
  #   encrypt = true
  #   dynamodb_table = "terraform-locks"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "auto-feedback"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.github_username
      DeploymentId = var.deployment_id
    }
  }
}

# Data sources for dynamic resource discovery
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get GitHub SSH keys for the specified user
data "http" "github_ssh_keys" {
  url = "https://github.com/${var.github_username}.keys"
}

# Local values for computed resources
locals {
  name_prefix = "${var.environment}-auto-feedback"

  # Common tags
  common_tags = {
    Project      = "auto-feedback"
    Environment  = var.environment
    ManagedBy    = "terraform"
    Owner        = var.github_username
    DeploymentId = var.deployment_id
  }

  # Network configuration
  vpc_cidr = "10.0.0.0/16"
  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  # Security groups
  allowed_cidr_blocks = var.environment == "production" ? var.allowed_cidr_blocks : ["0.0.0.0/0"]
}

# VPC Configuration
resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count = var.create_vpc ? length(local.public_subnets) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Type = "Public"
  })
}

resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc ? length(aws_subnet.public) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Security Groups
resource "aws_security_group" "app_server" {
  name_prefix = "${local.name_prefix}-app-"
  description = "Security group for Auto-Feedback application servers"
  vpc_id      = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidr_blocks
    tags = {
      Name = "SSH Access"
    }
  }

  # Flask API port
  ingress {
    description = "Flask API"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidr_blocks
    tags = {
      Name = "Flask API"
    }
  }

  # Streamlit Dashboard port
  ingress {
    description = "Streamlit Dashboard"
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidr_blocks
    tags = {
      Name = "Streamlit Dashboard"
    }
  }

  # HTTPS (if SSL enabled)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidr_blocks
    tags = {
      Name = "HTTPS"
    }
  }

  # HTTP (for health checks and redirects)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidr_blocks
    tags = {
      Name = "HTTP"
    }
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    tags = {
      Name = "All Outbound"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "alb" {
  count = var.load_balancer_enabled ? 1 : 0

  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for Auto-Feedback application load balancer"
  vpc_id      = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.default.id

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound to app servers
  egress {
    description     = "To app servers"
    from_port       = 5000
    to_port         = 8501
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server.id]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Get default VPC if not creating a new one
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "app_server" {
  name_prefix = "${local.name_prefix}-app-server-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "app_server" {
  name_prefix = "${local.name_prefix}-app-server-"
  role        = aws_iam_role.app_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.app_data.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app_server" {
  name_prefix = "${local.name_prefix}-app-server-"
  role        = aws_iam_role.app_server.name

  tags = local.common_tags
}

# Launch Template for instances
resource "aws_launch_template" "app_server" {
  name_prefix   = "${local.name_prefix}-"
  description   = "Launch template for Auto-Feedback application servers"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.app_server.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.app_server.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    github_ssh_keys = data.http.github_ssh_keys.response_body
    container_image = var.container_image
    environment     = var.environment
    deployment_id   = var.deployment_id
    bucket_name     = aws_s3_bucket.app_data.bucket
    region          = var.aws_region
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = var.enable_monitoring
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-instance"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-volume"
    })
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer (optional)
resource "aws_lb" "app" {
  count = var.load_balancer_enabled ? 1 : 0

  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]

  subnets = var.create_vpc ? aws_subnet.public[*].id : data.aws_subnets.default.ids

  enable_deletion_protection = var.environment == "production"

  access_logs {
    bucket  = aws_s3_bucket.app_data.bucket
    prefix  = "alb-access-logs"
    enabled = var.enable_monitoring
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "app_api" {
  count = var.load_balancer_enabled ? 1 : 0

  name     = "${local.name_prefix}-api-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-tg"
  })
}

resource "aws_lb_target_group" "app_dashboard" {
  count = var.load_balancer_enabled ? 1 : 0

  name     = "${local.name_prefix}-dash-tg"
  port     = 8501
  protocol = "HTTP"
  vpc_id   = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    path                = "/_stcore/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dashboard-tg"
  })
}

resource "aws_lb_listener" "app_http" {
  count = var.load_balancer_enabled ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.enable_ssl ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_ssl ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.enable_ssl ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.app_api[0].arn
        }
      }
    }
  }
}

resource "aws_lb_listener" "app_https" {
  count = var.load_balancer_enabled && var.enable_ssl ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_api[0].arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_server" {
  name                = "${local.name_prefix}-asg"
  vpc_zone_identifier = var.create_vpc ? aws_subnet.public[*].id : data.aws_subnets.default.ids
  min_size            = var.min_instances
  max_size            = var.max_instances
  desired_capacity    = var.instance_count
  health_check_type   = var.load_balancer_enabled ? "ELB" : "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_server.id
    version = "$Latest"
  }

  dynamic "target_group_arns" {
    for_each = var.load_balancer_enabled ? [1] : []
    content {
      target_group_arns = [
        aws_lb_target_group.app_api[0].arn,
        aws_lb_target_group.app_dashboard[0].arn
      ]
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes       = [desired_capacity]
  }
}

# S3 Bucket for application data and logs
resource "aws_s3_bucket" "app_data" {
  bucket = var.bucket_name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-data-bucket"
  })
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    id     = "lifecycle"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app_logs" {
  count = var.enable_monitoring ? 1 : 0

  name              = "/aws/ec2/${local.name_prefix}"
  retention_in_days = var.backup_retention_days

  tags = local.common_tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = []

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_server.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors memory utilization"
  alarm_actions       = []

  tags = local.common_tags
}
