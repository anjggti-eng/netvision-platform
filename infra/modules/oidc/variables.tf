variable "project_name" {
  type        = string
  description = "Prefixo dos recursos."
}

variable "github_repo" {
  type        = string
  description = "Repo GitHub no formato owner/name (ex.: anjggti-eng/netvision-platform)."
}

variable "state_bucket_arn" {
  type        = string
  description = "ARN do bucket de state (módulo bootstrap)."
}

variable "state_lock_table_arn" {
  type        = string
  description = "ARN da tabela de lock (módulo bootstrap)."
}
