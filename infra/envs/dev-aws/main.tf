provider "aws" {
  region  = "eu-north-1"
  profile = "myorg-dev"
}

# 1. Build your network infrastructure (VPC)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "myorg-dev-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-north-1a", "eu-north-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  single_nat_gateway = false # Keeps costs completely free/low for dev
}

# 2. Call your shared ECR and ECS module
module "ecr" {
  source     = "../../modules/aws-ecs"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
}
