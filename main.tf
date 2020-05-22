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
  version = ">= 2.62.0"
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
  version = "0.1.0-beta.27"

  cluster-name    = "scaut-v2-dev"
  ingress-acm-arn = "arn:aws:acm:eu-west-1:454089853750:certificate/300523fe-fe6f-49a0-9dbe-14ec94dc93cd"
}

provider "kubernetes" {
    version        = "~> 1.11"
    config_context = "scaut-v2-dev"
}

provider "kustomization" {
    kubeconfig_raw = module.cluster.kubeconfig
}

resource "kubernetes_namespace" "jenkins" {
    metadata {
        name = "openshift-build"
    }
}

resource "kubernetes_secret" "jenkins-github" {
    metadata {
        name = "github"
        namespace = "openshift-build"

        labels = {
            "jenkins.io/credentials-type" = "usernamePassword"
        }

        annotations = {
            "jenkins.io/credentials-description" = "Used to scan GitHub for jobs"
        }
    }

    data = {
        username = var.github_username
        password = var.github_access_token
    }
}

locals {
    google_oauth = {
        GOOGLE_CLIENT_ID      = var.google_client_id
        GOOGLE_CLIENT_SECRET  = var.google_client_secret
        GOOGLE_CLIENT_DOMAINS = var.google_client_domains
    }
}

resource "aws_iam_policy" "jenkins-secrets" {
    name        = "scaut-v2-dev-JenkinsSecrets"
    description = "Secrets used by Jenkins in development"
    path        = "/scaut-v2-dev/"

    policy =<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": [
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/openshift-build/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "jenkins-secrets" {
    name        = "scaut-v2-dev-secrets-manager-jenkins"
    description = "Allows the Kubernetes Secrets Manager to read Jenkins secrets"
    path        = "/secrets/scaut-v2-dev/openshift-build/"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::454089853750:role/scaut-v2-dev/scaut-v2-dev-SecretsManager"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "jenkins-secrets" {
  role       = aws_iam_role.jenkins-secrets.name
  policy_arn = aws_iam_policy.jenkins-secrets.arn
}

resource "aws_secretsmanager_secret" "jenkins-google-oauth" {
    name        = "scaut-v2-dev/openshift-build/jenkins-google-oauth"
    description = "Allows GSuite login for Jenkins"
}

resource "aws_secretsmanager_secret_version" "jenkins-google-oauth" {
    secret_id     = aws_secretsmanager_secret.jenkins-google-oauth.id
    secret_string = jsonencode(local.google_oauth)
}

resource "kubernetes_secret" "jenkins-ssh" {
    metadata {
        name = "jenkins-build"
        namespace = "openshift-build"
    }

    data = {
        ssh-privatekey = "${file("${path.module}/input/ssh-privatekey")}"
    }
}

resource "kubernetes_secret" "jenkins-pypi-config" {
    metadata {
        name = "pypi-config"
        namespace = "openshift-build"
    }

    data = {
        "auth.toml"   = "${file("${path.module}/input/auth.toml")}"
        "config.toml" = "${file("${path.module}/input/config.toml")}"
        password      = var.pypi_password
        username      = var.pypi_username
    }
}

data "kustomization" "jenkins" {
    path = "jenkins"
}

resource "kustomization_resource" "jenkins" {
    for_each = data.kustomization.jenkins.ids

    manifest = data.kustomization.jenkins.manifests[each.value]
}