# ============================================================
# VARIABLES - Engineering Secret Standard
# ============================================================

variable "project_name" {
  description = "Project name used as prefix for resource names"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production"
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ============================================================
# LOCALSTACK CONFIGURATION
# ============================================================

variable "use_localstack" {
  description = "Whether to use LocalStack for local development"
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}

# ============================================================
# TAGGING / GOVERNANCE
# ============================================================

variable "owner_team" {
  description = <<-EOT
    Team that owns these resources. Used for ABAC and governance.
    
    Examples: platform, payments, billing, analytics
  EOT
  type        = string
  default     = "platform"
}

# ============================================================
# SECRET CONFIGURATION
# ============================================================

variable "recovery_window_days" {
  description = "Number of days to retain a deleted secret (7-30 for production)"
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_days >= 0 && var.recovery_window_days <= 30
    error_message = "Recovery window must be between 0 and 30 days"
  }
}

# ============================================================
# FLOW A: RDS PASSWORD ROTATION
# ============================================================

variable "rds_password_version" {
  description = <<-EOT
    Version number for RDS password rotation.
    Increment to rotate the password.
    
    Example:
      - Initial deploy: rds_password_version = 1
      - First rotation: rds_password_version = 2
  EOT
  type        = number
  default     = 1
}

# ============================================================
# VARIABLE SUMMARY
# ============================================================
#
# FLOW A (TF-Generated):
#   rds_password_version : Bump to rotate RDS password
#
# FLOW B (Third-Party):
#   No variables needed - apps read secrets at runtime
#
# ============================================================
