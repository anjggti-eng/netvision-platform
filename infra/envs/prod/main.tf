module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  admin_cidr   = var.admin_cidr
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  subnet_id    = module.network.public_subnet_id
  sg_id        = module.network.sg_cluster_id
}

module "budget" {
  source = "../../modules/budget"

  project_name     = var.project_name
  budget_email     = var.budget_email
  budget_limit_usd = var.budget_limit_usd
}

data "aws_caller_identity" "current" {}

locals {
  state_bucket     = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"
  state_lock_table = "${var.project_name}-tflock"
}

module "oidc" {
  source = "../../modules/oidc"

  project_name         = var.project_name
  github_repo          = var.github_repo
  state_bucket_arn     = "arn:aws:s3:::${local.state_bucket}"
  state_lock_table_arn = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${local.state_lock_table}"
}
