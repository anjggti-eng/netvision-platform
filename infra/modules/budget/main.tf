resource "aws_sns_topic" "billing" {
  name = "${var.project_name}-billing-alerts"

  tags = {
    Name = "${var.project_name}-billing"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.billing.arn
  protocol  = "email"
  endpoint  = var.budget_email
}

resource "aws_budgets_budget" "guardrail" {
  name              = "${var.project_name}-monthly"
  budget_type       = "COST"
  limit_amount      = var.budget_limit_usd
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  cost_filter {
    name = "TagKeyValue"
    # filtra apenas recursos da plataforma (tag ManagedBy=terraform)
    values = ["user:Project$netvision-platform"]
  }

  notification {
    notification_type          = "ACTUAL"
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    notification_type          = "FORECASTED"
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_email]
  }
}

output "billing_topic_arn" {
  description = "ARN do SNS de alertas de custo."
  value       = aws_sns_topic.billing.arn
}
