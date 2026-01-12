# ============================================================
# TERRAFORM CONFIGURATION FOR AWS SECRETS MANAGER
# Engineering Standard: Flow A + Flow B
# ============================================================
#
# NAMING CONVENTION: /{env}/{app}/{purpose}
#   env:     dev | staging | prod
#   app:     project/service name
#   purpose: stripe-api-key | sendgrid-api-key | oauth-credentials
#
# ============================================================

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # For production, use S3 backend with encryption:
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "secrets-poc/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   kms_key_id     = "alias/terraform-state"
  #   dynamodb_table = "terraform-locks"
  # }
}

# ============================================================
# PROVIDER CONFIGURATION
# ============================================================

provider "aws" {
  region = var.region

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      secretsmanager = var.localstack_endpoint
      sts            = var.localstack_endpoint
      iam            = var.localstack_endpoint
      rds            = var.localstack_endpoint
      ec2            = var.localstack_endpoint
    }
  }

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null
}

# ============================================================
# LOCAL VARIABLES
# ============================================================

locals {
  # Environment short name for naming
  env_short = {
    development = "dev"
    staging     = "staging"
    production  = "prod"
  }

  # Third-party secrets configuration (Flow B)
  # Naming: /{env}/{app}/{purpose}
  third_party_secrets = {
    stripe = {
      purpose     = "stripe-api-key"
      description = "Stripe API key. Third-party owned, seeded externally."
      secret_type = "api-key"
      owner_team  = var.owner_team
      data_class  = "secret"
    }
    sendgrid = {
      purpose     = "sendgrid-api-key"
      description = "SendGrid API key. Third-party owned, seeded externally."
      secret_type = "api-key"
      owner_team  = var.owner_team
      data_class  = "secret"
    }
    oauth = {
      purpose     = "oauth-credentials"
      description = "OAuth client credentials. Third-party owned."
      secret_type = "oauth-credentials"
      owner_team  = var.owner_team
      data_class  = "secret"
    }
  }

  # Common tags for all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    OwnerTeam   = var.owner_team
  }
}

# ============================================================
# FLOW B: THIRD-PARTY SECRETS
# ============================================================
# Terraform creates empty secret containers. Engineers seed values.
# Applications read secrets at runtime via AWS SDK.
#
# NAMING: /{env}/{app}/{purpose}
# Example: /dev/myapp/stripe-api-key
#
# FLOW B LIFECYCLE:
#   1. Terraform creates shell (this resource)
#   2. Engineer creates key in third-party (Stripe, etc.)
#   3. Engineer seeds value: node scripts/secrets.js seed
#   4. Application reads at runtime: secretsManager.getSecretValue()
#
# WHY SHELLS?
#   - Consistent naming (IaC)
#   - Tags/metadata managed by Terraform
#   - IAM policies can reference ARN before seeding
# ============================================================

resource "aws_secretsmanager_secret" "third_party" {
  for_each = local.third_party_secrets

  # Naming: /{env}/{app}/{purpose}
  name        = "/${local.env_short[var.environment]}/${var.project_name}/${each.value.purpose}"
  description = each.value.description

  recovery_window_in_days = var.use_localstack ? 0 : var.recovery_window_days

  tags = merge(local.common_tags, {
    SecretType = each.value.secret_type
    SecretFlow = "B-third-party"
    DataClass  = each.value.data_class
  })

  lifecycle {
    prevent_destroy = false # Set to true for production!
  }
}

# ============================================================
# FLOW A: TF-GENERATED SECRETS (Write-Only to Target)
# ============================================================
# For secrets that Terraform generates:
# 1. Generate ephemerally (never in state)
# 2. Inject via write-only argument to target system
# 3. Target system becomes the record
# 4. Apps use IAM auth or runtime identity to access
# ============================================================

# Ephemeral password for RDS (Flow A)
ephemeral "random_password" "rds_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# VPC for RDS (skipped in LocalStack - RDS requires Pro)
resource "aws_vpc" "main" {
  count = var.use_localstack ? 0 : 1

  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_subnet" "db_a" {
  count = var.use_localstack ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-subnet-a"
  })
}

resource "aws_subnet" "db_b" {
  count = var.use_localstack ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-subnet-b"
  })
}

resource "aws_db_subnet_group" "main" {
  count = var.use_localstack ? 0 : 1

  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.db_a[0].id, aws_subnet.db_b[0].id]

  tags = local.common_tags
}

# RDS Instance - FLOW A (skipped in LocalStack - requires Pro)
# Password is:
# 1. Generated ephemerally (never in state)
# 2. Injected via password_wo (write-only)
# 3. Stored only in RDS
# 4. Apps use IAM database authentication
resource "aws_db_instance" "main" {
  count = var.use_localstack ? 0 : 1

  identifier     = "${var.project_name}-db-${local.env_short[var.environment]}"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "appdb"
  username = "dbadmin"

  # FLOW A: Write-only password
  # - Generated ephemerally above
  # - Sent to AWS/LocalStack during apply
  # - NEVER stored in terraform.tfstate
  # - Bump rds_password_version to rotate
  password_wo         = ephemeral.random_password.rds_master.result
  password_wo_version = var.rds_password_version

  db_subnet_group_name = aws_db_subnet_group.main[0].name
  skip_final_snapshot  = true

  # Enable IAM database authentication
  iam_database_authentication_enabled = true

  tags = merge(local.common_tags, {
    SecretFlow = "A-tf-generated"
    DataClass  = "secret"
  })
}

# ============================================================
# FLOW SUMMARY
# ============================================================
#
# NAMING: /{env}/{app}/{purpose}
#
# FLOW A (TF-Generated):
#   Pattern: ephemeral random_password -> password_wo -> Target
#   Example: RDS password
#   Rotation: Bump rds_password_version
#   App Access: IAM database authentication
#
# FLOW B (Third-Party):
#   Pattern: TF creates shell -> Engineer seeds -> App reads at runtime
#   Example: Stripe API key, SendGrid API key
#   Rotation: Get new key from vendor -> re-seed
#   App Access: AWS SDK secretsManager.getSecretValue()
#
# ============================================================
