module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  admin_cidr   = var.admin_cidr
}
