# ============================================================
# OUTPUTS - Engineering Secret Standard
# ============================================================

# ============================================================
# FLOW B: THIRD-PARTY SECRETS
# ============================================================

output "third_party_secret_arns" {
  description = "ARNs of third-party secrets (for IAM policies)"
  value       = { for k, v in aws_secretsmanager_secret.third_party : k => v.arn }
}

output "third_party_secret_names" {
  description = "Names of third-party secrets"
  value       = { for k, v in aws_secretsmanager_secret.third_party : k => v.name }
}

# ============================================================
# FLOW A: RDS (only when not using LocalStack)
# ============================================================

output "rds_endpoint" {
  description = "RDS instance endpoint - apps connect here with IAM auth"
  value       = length(aws_db_instance.main) > 0 ? aws_db_instance.main[0].endpoint : "N/A (LocalStack mode - RDS requires Pro)"
}

output "rds_database_name" {
  description = "RDS database name"
  value       = length(aws_db_instance.main) > 0 ? aws_db_instance.main[0].db_name : "appdb"
}

output "rds_username" {
  description = "RDS master username"
  value       = length(aws_db_instance.main) > 0 ? aws_db_instance.main[0].username : "dbadmin"
}

output "rds_iam_auth_enabled" {
  description = "Whether IAM database authentication is enabled"
  value       = length(aws_db_instance.main) > 0 ? aws_db_instance.main[0].iam_database_authentication_enabled : true
}

output "vpc_id" {
  description = "VPC ID"
  value       = length(aws_vpc.main) > 0 ? aws_vpc.main[0].id : "N/A (LocalStack mode)"
}

# ============================================================
# CONFIGURATION INFO
# ============================================================

output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "environment_short" {
  description = "Short environment name (dev/staging/prod)"
  value       = local.env_short[var.environment]
}

output "localstack_mode" {
  description = "Whether LocalStack is being used"
  value       = var.use_localstack
}

output "owner_team" {
  description = "Team that owns these resources"
  value       = var.owner_team
}

# ============================================================
# NAMING CONVENTION
# ============================================================

output "naming_convention" {
  description = "Secret naming convention used"
  value       = "/{env}/{app}/{purpose}"
}

output "naming_example" {
  description = "Example secret name"
  value       = "/${local.env_short[var.environment]}/${var.project_name}/stripe-api-key"
}

# ============================================================
# SEED COMMANDS (Flow B)
# ============================================================

output "seed_commands" {
  description = "Commands to seed third-party secrets after initial apply"
  value       = <<-EOT

    # After terraform apply, seed the third-party secrets:
    node scripts/secrets.js seed

    # Or manually:
    ${var.use_localstack ? "ENDPOINT='--endpoint-url http://localhost:4566'" : "ENDPOINT=''"}
    %{for k, v in aws_secretsmanager_secret.third_party~}
    aws secretsmanager put-secret-value \
      --secret-id "${v.name}" \
      --secret-string '{"api_key":"YOUR_${upper(k)}_KEY"}' \
      $ENDPOINT --region ${var.region}
    %{endfor~}

  EOT
}

# ============================================================
# FLOW SUMMARY
# ============================================================

output "flow_summary" {
  description = "Summary of implemented secret flows"
  value       = <<-EOT

    NAMING: /{env}/{app}/{purpose}

    FLOW A (TF-Generated) - RDS:
      Pattern: ephemeral -> password_wo -> RDS
      Endpoint: ${length(aws_db_instance.main) > 0 ? aws_db_instance.main[0].endpoint : "N/A (LocalStack mode - RDS requires Pro)"}
      Rotation: Bump rds_password_version (current: ${var.rds_password_version})
      App Access: IAM database authentication

    FLOW B (Third-Party) - Secrets Manager:
      Secrets:
        - /${local.env_short[var.environment]}/${var.project_name}/stripe-api-key
        - /${local.env_short[var.environment]}/${var.project_name}/sendgrid-api-key
        - /${local.env_short[var.environment]}/${var.project_name}/oauth-credentials
      Pattern: TF creates shell -> Engineer seeds -> App reads at runtime
      Rotation: Get new key from vendor -> re-seed
      App Access: AWS SDK secretsManager.getSecretValue()

  EOT
}
