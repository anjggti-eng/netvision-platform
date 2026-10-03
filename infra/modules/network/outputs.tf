output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "ID da subnet pública."
  value       = aws_subnet.public.id
}

output "sg_cluster_id" {
  description = "ID do security group do cluster."
  value       = aws_security_group.cluster.id
}

output "public_route_table_id" {
  description = "ID da route table pública."
  value       = aws_route_table.public.id
}
