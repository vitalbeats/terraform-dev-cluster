terraform {
  backend "s3" {
    bucket = "vitalbeats-terraform-state"
    dynamodb_table = "vitalbeats-terraform-state-lock"
    key    = "terraform-eks/dev"
    region = "eu-west-1"
    encrypt = true
  }
}