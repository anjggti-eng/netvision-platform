output "vpc_id" {
  description = "ID da VPC."
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "ID da subnet pública dos nós k3s."
  value       = module.network.public_subnet_id
}

output "sg_cluster_id" {
  description = "ID do security group do cluster."
  value       = module.network.sg_cluster_id
}

output "asg_name" {
  description = "ASG dos nós k3s."
  value       = module.compute.asg_name
}

output "k3s_instance_tag" {
  description = "Tag para descobrir a instância."
  value       = module.compute.k3s_instance_tag
}
