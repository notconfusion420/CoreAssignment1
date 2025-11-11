module "tgw" {
  source = "./modules/tgw"
  name   = "core-tgw"
}

module "hub" {
  source             = "./modules/hub-vpc"
  name               = "hub"
  vpc_cidr           = "10.0.0.0/16"
  az_a               = "eu-central-1a"
  az_b               = "eu-central-1b"
  tgw_id             = module.tgw.id
  tgw_route_table_id = module.tgw.route_table_id
  spoke_cidrs        = ["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"]

  app_vpc_id           = module.app.vpc_id
  data_vpc_id          = module.data.vpc_id
  db_vpc_id            = module.db.vpc_id
  app_vpc_cidr         = "10.1.0.0/16"
  data_vpc_cidr        = "10.2.0.0/16"
  db_vpc_cidr          = "10.3.0.0/16"
  admin_instance_sg_id = module.data.admin_instance_sg_id
}



module "app" {
  source = "./modules/app-vpc"
  name   = "app"

  vpc_cidr       = "10.1.0.0/16"
  public_a_cidr  = "10.1.1.0/24"
  private_a_cidr = "10.1.2.0/24"
  az_a           = "eu-central-1a"

  tgw_id       = module.tgw.id
  spoke_cidrs  = ["10.0.0.0/16", "10.2.0.0/16", "10.3.0.0/16"]
  hub_vpc_cidr = "10.0.0.0/16"

  app_ami_id                = "ami-0e1fff6d10aa3c1fe" # replace with real AMI
  app_instance_type         = "t3.micro"
  app_instance_profile_name = "app-ssm-profile"

}

module "db" {
  source                     = "./modules/db-vpc"
  name                       = "db"
  vpc_cidr                   = "10.2.0.0/16"
  az_a                       = "eu-central-1a"
  az_b                       = "eu-central-1b"
  region                     = var.region
  tgw_id                     = module.tgw.id
  tgw_route_table_id         = module.tgw.route_table_id
  spoke_cidrs                = ["10.0.0.0/16", "10.1.0.0/16", "10.3.0.0/16"]
  tags                       = { Owner = "fares", Env = "dev" }
  hub_dns_ip                 = module.hub.dns_instance_private_ip
  enable_s3_gateway_endpoint = true
  rds_password               = "ChangeMeNOW_SuperSecret123!"
}


module "data" {
  source = "./modules/data-vpc"
  name   = "data"

  vpc_cidr       = "10.3.0.0/16"
  private_a_cidr = "10.3.1.0/24"
  az_a           = "eu-central-1a"

  tgw_id      = module.tgw.id
  spoke_cidrs = ["10.0.0.0/16", "10.1.0.0/16", "10.2.0.0/16"]

  admin_ami_id                = "ami-0e1fff6d10aa3c1fe" # replace with your AMI
  admin_instance_type         = "t3.micro"
  admin_instance_profile_name = "admin-ssm-profile"
}



module "monitoring" {
  source        = "./modules/monitoring"
  name          = "mon"
  vpc_id        = module.hub.vpc_id
  subnet_id     = module.hub.public_subnet_ids[0]
  key_name      = "my-ssh-key"
  instance_type = "t3.medium"
  allowed_cidrs = ["85.145.236.171/32"]
  tags          = var.tags
}

