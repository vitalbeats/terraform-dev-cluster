module "cluster" {
  source  = "vitalbeats/cluster/eks"
  version = "0.1.0-alpha"

  cluster-name = "scaut-v2-dev"
}