# ============================================================
# Staging Configuration (AWS)
# Engineering Secret Standard: Flow A + Flow B
# ============================================================
# NO secrets in this file! Only infrastructure configuration.
# ============================================================

project_name = "myapp"
environment  = "staging"
region       = "us-east-1"

# Staging uses real AWS
use_localstack = false

# 14-day recovery window for staging
recovery_window_days = 14

# ============================================================
# FLOW A: RDS (password_wo)
# ============================================================

rds_password_version = 1

# ============================================================
# FLOW B: THIRD-PARTY SECRETS
# ============================================================
# After apply, run: node scripts/secrets.js seed
