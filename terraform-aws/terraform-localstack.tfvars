# ============================================================
# LocalStack Development Configuration
# Engineering Secret Standard: Flow A + Flow B
# ============================================================
# NO secrets in this file! Only infrastructure configuration.
# ============================================================

project_name = "myapp"
environment  = "development"
region       = "us-east-1"

# LocalStack configuration
use_localstack      = true
localstack_endpoint = "http://localhost:4566"

# Recovery window 0 for LocalStack (allows immediate delete/recreate)
recovery_window_days = 0

# ============================================================
# FLOW A: RDS (password_wo)
# ============================================================
# Password generated ephemerally, injected via password_wo
# Apps use IAM database authentication

rds_password_version = 1

# ============================================================
# FLOW B: THIRD-PARTY SECRETS
# ============================================================
# After apply, run: node scripts/secrets.js seed
