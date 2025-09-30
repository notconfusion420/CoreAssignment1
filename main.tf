module "tgw" {
  source = "./modules/tgw"
  name   = "core-tgw"
}

module "hub" {
  source             = "./modules/hub-vpc"
  name               = "hub"
  region             = var.region
  tgw_id             = module.tgw.id
  tgw_route_table_id = module.tgw.route_table_id
  spoke_cidrs        = ["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"] # App, DB, Data
}

module "app" {
  source             = "./modules/app-vpc"
  name               = "app"
  vpc_cidr           = "10.1.0.0/16"
  az_a               = "eu-central-1a"
  az_b               = "eu-central-1b"
  region             = var.region
  tgw_id             = module.tgw.id
  tgw_route_table_id = module.tgw.route_table_id
  spoke_cidrs        = ["10.0.0.0/16", "10.2.0.0/16", "10.3.0.0/16"]
  tags = {
    Owner = "fares"
    Env   = "dev"
  }
}

module "db" {
  source             = "./modules/db-vpc"
  name               = "db"
  region             = var.region
  tgw_id             = module.tgw.id
  tgw_route_table_id = module.tgw.route_table_id
  spoke_cidrs        = ["10.0.0.0/16", "10.1.0.0/16", "10.3.0.0/16"] # Hub, App, Data
  rds_password       = "ChangeMeNOW_SuperSecret123!"
}

module "data" {
  source             = "./modules/data-vpc"
  name               = "data"
  vpc_cidr           = "10.3.0.0/16"   # Data VPC CIDR
  az_a               = "eu-central-1a"
  az_b               = "eu-central-1b"
  tgw_id             = module.tgw.id
  tgw_route_table_id = module.tgw.route_table_id
  spoke_cidrs        = ["10.0.0.0/16", "10.1.0.0/16", "10.2.0.0/16"] # Hub, App, DB
  tags               = {
    Owner = "fares"
    Env   = "dev"
  }
}


