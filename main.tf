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
  spoke_cidrs        = ["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"]
}

resource "aws_ec2_transit_gateway_route" "default_to_hub" {
  transit_gateway_route_table_id = module.tgw.route_table_id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.hub.tgw_attachment_id
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
  tags               = {
    Owner = "fares"
    Env   = "dev"
  }
  hub_dns_ip               = module.hub.dns_instance_private_ip
  enable_gateway_endpoints = true
}

module "db" {
  source             = "./modules/db-vpc"
  name               = "db"
  vpc_cidr           = "10.2.0.0/16"
  az_a               = "eu-central-1a"
  az_b               = "eu-central-1b"
  region             = var.region
  tgw_id             = module.tgw.id
  tgw_route_table_id = module.tgw.route_table_id
  spoke_cidrs        = ["10.0.0.0/16", "10.1.0.0/16", "10.3.0.0/16"]
  tags               = { Owner = "fares", Env = "dev" }
  hub_dns_ip                 = module.hub.dns_instance_private_ip
  enable_s3_gateway_endpoint = true
  rds_password               = "ChangeMeNOW_SuperSecret123!"
}


module "data" {
  source             = "./modules/data-vpc"
  name               = "data"
  vpc_cidr           = "10.3.0.0/16"
  az_a               = "eu-central-1a"
  az_b               = "eu-central-1b"
  tgw_id             = module.tgw.id
  tgw_route_table_id = module.tgw.route_table_id
  spoke_cidrs        = ["10.0.0.0/16", "10.1.0.0/16", "10.2.0.0/16"]
  tags               = { Owner = "fares", Env = "dev" }
  hub_dns_ip               = module.hub.dns_instance_private_ip
  enable_gateway_endpoints = true
  region                   = var.region
}


module "monitoring" {
  source        = "./modules/monitoring"
  name          = "mon"
  vpc_id        = module.hub.vpc_id
  subnet_id     = module.hub.public_subnet_ids[0]
  key_name      = "my-ssh-key"
  allowed_cidrs = ["85.145.236.171/32"]
  tags          = var.tags
}
