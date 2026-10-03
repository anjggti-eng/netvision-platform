variable "project_name" {
  type        = string
  description = "Prefixo dos recursos."
}

variable "budget_email" {
  type        = string
  description = "E-mail que recebe alertas de custo (confirmação SNS é necessária)."
}

variable "budget_limit_usd" {
  type        = string
  default     = "5"
  description = "Limite mensal do budget em USD (guarda de custo — spec §4)."
}
