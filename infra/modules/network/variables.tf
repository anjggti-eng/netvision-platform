variable "project_name" {
  type        = string
  description = "Prefixo de nomes dos recursos."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR da VPC."
}

variable "admin_cidr" {
  type        = string
  description = "CIDR autorizado no SSH (22/tcp), ex.: 189.1.2.3/32."
}
