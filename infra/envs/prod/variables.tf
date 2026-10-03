variable "region" {
  type        = string
  default     = "sa-east-1"
  description = "AWS region (São Paulo)."
}

variable "project_name" {
  type        = string
  default     = "netvision"
  description = "Prefixo dos recursos."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR da VPC."
}

variable "admin_cidr" {
  type        = string
  description = "CIDR autorizado no SSH (22/tcp). NUNCA use 0.0.0.0/0 — ex.: 189.1.2.3/32."
}

variable "budget_email" {
  type        = string
  description = "E-mail para alertas de custo (budget US$5)."
}

variable "budget_limit_usd" {
  type        = string
  default     = "5"
  description = "Limite mensal USD do budget guardrail."
}

variable "github_repo" {
  type        = string
  default     = "anjggti-eng/netvision-platform"
  description = "Repo GitHub (owner/name) autorizado a assumir a role OIDC."
}
