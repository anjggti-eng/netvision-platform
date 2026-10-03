variable "project_name" {
  type        = string
  description = "Prefixo de nomes dos recursos."
}

variable "vpc_id" {
  type        = string
  description = "ID da VPC (referencia, para tag/policy)."
}

variable "subnet_id" {
  type        = string
  description = "Subnet pública onde o ASG sobe os nós."
}

variable "sg_id" {
  type        = string
  description = "Security group dos nós k3s."
}

variable "instance_type" {
  type        = string
  default     = "t4g.medium"
  description = "Tipo base spot (ARM64)."
}
