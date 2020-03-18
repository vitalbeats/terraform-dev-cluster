module "cluster" {
  source  = "vitalbeats/cluster/eks"
  version = "0.1.0-beta.3"
  
  cluster-name = "scaut-v2-dev"
  cluster-region = "eu-west-1"
}