output "gha_role_arn" {
  description = "ARN da role OIDC do GitHub Actions (setar em GH variable AWS_ROLE_ARN)."
  value       = aws_iam_role.gha.arn
}
