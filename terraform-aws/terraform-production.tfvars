# ============================================================
# Production Configuration
# Engineering Secret Standard: Flow A + Flow B
# ============================================================
# NO secrets in this file! Only infrastructure configuration.
# ============================================================

project_name = "myapp"
environment  = "production"
region       = "us-east-1"

# Production uses real AWS
use_localstack = false

# 30-day recovery window for production secrets
recovery_window_days = 30

# ============================================================
# FLOW A: RDS (password_wo)
# ============================================================
# Password generated ephemerally, injected via password_wo
# Incrementing rds_password_version rotates the password
# Coordinate with application team before rotating!

rds_password_version = 1

# ============================================================
# FLOW B: THIRD-PARTY SECRETS
# ============================================================
# Secrets seeded via CI/CD or manual workflow
