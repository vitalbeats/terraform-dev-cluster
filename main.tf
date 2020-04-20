terraform {
  backend "s3" {
    bucket = "vitalbeats-terraform-state"
    dynamodb_table = "vitalbeats-terraform-state-lock"
    key    = "terraform-eks/dev"
    region = "eu-west-1"
    encrypt = true
  }
}

provider "aws" {
  version = "~> 2.0"
  region = "eu-west-1"
}

provider "local" {
  version = "~> 1.4"
}

provider "null" {
  version = "~> 2.1"
}

module "cluster" {
  source  = "vitalbeats/cluster/eks"
  version = "0.1.0-beta.11"

  cluster-name    = "scaut-v2-dev"
  ingress-acm-arn = "arn:aws:acm:eu-west-1:454089853750:certificate/300523fe-fe6f-49a0-9dbe-14ec94dc93cd"
}