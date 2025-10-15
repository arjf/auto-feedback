# Auto-Feedback Application Terraform Variables
# This file defines all configurable variables for the infrastructure

# ================================================
# Basic Configuration
# ================================================

variable "aws_region" {
  description = "The AWS region where resources will be created"
  type        = string
  default     = "us-east-1"

  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format: us-east-1, eu-west-1, etc."
  }
}

variable "environment" {
  description = "The deployment environment (staging, production, development)"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production", "development"], var.environment)
    error_message = "Environment must be one of: staging, production, development."
  }
}

variable "deployment_id" {
  description = "Unique identifier for this deployment"
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]*$", var.deployment_id))
    error_message = "Deployment ID must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "github_username" {
  description = "GitHub username to fetch SSH keys from"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.github_username))
    error_message = "GitHub username must contain only alphanumeric characters and hyphens."
  }
}

# ================================================
# Application Configuration
# ================================================

variable "container_image" {
  description = "Docker container image to deploy"
  type        = string
  default     = "ghcr.io/kaushik1919/auto-feedback:latest"

  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+/[a-zA-Z0-9.-]+:[a-zA-Z0-9.-]+$", var.container_image))
    error_message = "Container image must be in the format: registry/repository:tag."
  }
}

# ================================================
# Compute Configuration
# ================================================

variable "instance_type" {
  description = "EC2 instance type for the application servers"
  type        = string
  default     = "t3.small"

  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge",
      "t3a.micro", "t3a.small", "t3a.medium", "t3a.large", "t3a.xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a valid AWS instance type suitable for the workload."
  }
}

variable "instance_count" {
  description = "Number of instances to run"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "min_instances" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1

  validation {
    condition     = var.min_instances >= 1 && var.min_instances <= 5
    error_message = "Minimum instances must be between 1 and 5."
  }
}

variable "max_instances" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 3

  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 20
    error_message = "Maximum instances must be between 1 and 20."
  }
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access (optional, uses GitHub SSH keys if not provided)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB."
  }
}

# ================================================
# Network Configuration
# ================================================

variable "create_vpc" {
  description = "Whether to create a new VPC or use the default VPC"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the application"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid CIDR notation (e.g., 10.0.0.0/16)."
  }
}

# ================================================
# Load Balancer Configuration
# ================================================

variable "load_balancer_enabled" {
  description = "Whether to create an Application Load Balancer"
  type        = bool
  default     = false
}

variable "enable_ssl" {
  description = "Whether to enable SSL/HTTPS"
  type        = bool
  default     = false
}

variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS (required if enable_ssl is true)"
  type        = string
  default     = ""

  validation {
    condition = var.enable_ssl == false || (var.enable_ssl == true && var.ssl_certificate_arn != "")
    error_message = "SSL certificate ARN is required when SSL is enabled."
  }
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""

  validation {
    condition = var.domain_name == "" || can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain format (e.g., example.com)."
  }
}

# ================================================
# Storage Configuration
# ================================================

variable "bucket_name" {
  description = "Name of the S3 bucket for application data and logs"
  type        = string
  default     = ""

  validation {
    condition = var.bucket_name == "" || can(regex("^[a-z0-9.-]{3,63}$", var.bucket_name))
    error_message = "S3 bucket name must be 3-63 characters long and contain only lowercase letters, numbers, periods, and hyphens."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain backups and logs"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}

# ================================================
# Monitoring and Logging
# ================================================

variable "enable_monitoring" {
  description = "Whether to enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Whether to enable detailed CloudWatch monitoring (additional cost)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14

  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be one of the valid CloudWatch log retention periods."
  }
}

# ================================================
# Security Configuration
# ================================================

variable "enable_encryption" {
  description = "Whether to enable encryption for EBS volumes and S3 buckets"
  type        = bool
  default     = true
}

variable "enable_imdsv2" {
  description = "Whether to require IMDSv2 for EC2 instance metadata"
  type        = bool
  default     = true
}

variable "ssh_access_cidr_blocks" {
  description = "List of CIDR blocks allowed SSH access (defaults to allowed_cidr_blocks if empty)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.ssh_access_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH access CIDR blocks must be valid CIDR notation."
  }
}

# ================================================
# High Availability Configuration
# ================================================

variable "multi_az" {
  description = "Whether to deploy across multiple availability zones"
  type        = bool
  default     = false
}

variable "enable_auto_scaling" {
  description = "Whether to enable auto scaling based on metrics"
  type        = bool
  default     = false
}

variable "cpu_scale_up_threshold" {
  description = "CPU utilization threshold to trigger scale up (percentage)"
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_scale_up_threshold >= 50 && var.cpu_scale_up_threshold <= 95
    error_message = "CPU scale up threshold must be between 50 and 95 percent."
  }
}

variable "cpu_scale_down_threshold" {
  description = "CPU utilization threshold to trigger scale down (percentage)"
  type        = number
  default     = 30

  validation {
    condition     = var.cpu_scale_down_threshold >= 10 && var.cpu_scale_down_threshold <= 50
    error_message = "CPU scale down threshold must be between 10 and 50 percent."
  }
}

# ================================================
# Cost Optimization
# ================================================

variable "spot_instances_enabled" {
  description = "Whether to use spot instances for cost savings (not recommended for production)"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Maximum price for spot instances (USD per hour)"
  type        = string
  default     = ""

  validation {
    condition = var.spot_max_price == "" || can(regex("^[0-9]+(\\.[0-9]+)?$", var.spot_max_price))
    error_message = "Spot max price must be a valid decimal number or empty string."
  }
}

# ================================================
# Environment-Specific Overrides
# ================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.tags : can(regex("^[a-zA-Z0-9._:/=+@-]+$", key)) && can(regex("^[a-zA-Z0-9._:/=+@-]*$", value))
    ])
    error_message = "Tag keys and values must contain only valid characters."
  }
}

# ================================================
# Feature Flags
# ================================================

variable "enable_waf" {
  description = "Whether to enable AWS WAF (Web Application Firewall)"
  type        = bool
  default     = false
}

variable "enable_shield" {
  description = "Whether to enable AWS Shield Standard protection"
  type        = bool
  default     = false
}

variable "enable_backup" {
  description = "Whether to enable automated backups using AWS Backup"
  type        = bool
  default     = false
}

variable "enable_secrets_manager" {
  description = "Whether to use AWS Secrets Manager for sensitive configuration"
  type        = bool
  default     = false
}

# ================================================
# Development/Testing Configuration
# ================================================

variable "create_test_data" {
  description = "Whether to create test data and configurations (development only)"
  type        = bool
  default     = false
}

variable "debug_mode" {
  description = "Whether to enable debug mode with additional logging and relaxed security"
  type        = bool
  default     = false
}

variable "preserve_on_delete" {
  description = "Whether to preserve resources when destroying the stack (useful for debugging)"
  type        = bool
  default     = false
}
