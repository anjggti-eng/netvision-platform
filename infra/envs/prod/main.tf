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
