data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Confiança GitHub Actions → AWS (sem chaves estáticas no repo).
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "gha" {
  name = "${var.project_name}-gha-plan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # restringe a este repo específico
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })
}

# Permissão mínima para `terraform plan` em PRs.
resource "aws_iam_role_policy" "plan" {
  name = "plan-only"
  role = aws_iam_role.gha.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          var.state_bucket_arn,
          "${var.state_bucket_arn}/*"
        ]
      },
      {
        Sid    = "StateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = var.state_lock_table_arn
      },
      {
        Sid    = "ReadInfrastructureForPlan"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:Get*",
          "elasticloadbalancing:Describe*",
          "autoscaling:Describe*",
          "ssm:GetParameter*",
          "ssm:Describe*",
          "iam:Get*",
          "iam:List*",
          "iam:Simulate*",
          "budgets:View*",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "budgets:Describe*",
          "sns:Get*",
          "sns:List*",
          "ecr:Describe*",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Sid      = "PlanOnlyNoWrites"
        Effect   = "Deny"
        Action   = ["ec2:Create*", "ec2:Delete*", "ec2:Terminate*", "ec2:Modify*", "s3:DeleteBucket", "dynamodb:DeleteTable"]
        Resource = "*"
      }
    ]
  })
}
