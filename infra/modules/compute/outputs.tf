output "asg_name" {
  description = "Nome do ASG dos nós k3s."
  value       = aws_autoscaling_group.k3s.name
}

output "k3s_instance_tag" {
  description = "Tag Name usada para descobrir a instância (verify_cluster.sh)."
  value       = "${var.project_name}-k3s"
}

output "node_role_arn" {
  description = "ARN da instance role (acesso SSM)."
  value       = aws_iam_role.node.arn
}
