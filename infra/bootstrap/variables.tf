variable "region" {
  type        = string
  default     = "sa-east-1"
  description = "AWS region (São Paulo — mercado BR)."
}

variable "project_name" {
  type        = string
  default     = "netvision"
  description = "Prefixo dos recursos de state."
}
