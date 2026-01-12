# ============================================================
# Development Configuration (AWS)
# Engineering Secret Standard: Flow A + Flow B
# ============================================================
# NO secrets in this file! Only infrastructure configuration.
# ============================================================

project_name = "myapp"
environment  = "development"
region       = "eu-west-2"

# Development uses real AWS
use_localstack = false

# 7-day recovery window for development
recovery_window_days = 7

# ============================================================
# FLOW A: RDS (password_wo)
# ============================================================

rds_password_version = 1

# ============================================================
# FLOW B: THIRD-PARTY SECRETS
# ============================================================
# After apply, run: node scripts/secrets.js seed
