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

resource "kubernetes_secret" "jenkins-google-oauth" {
    metadata {
        name = "google-oauth"
        namespace = "openshift-build"
    }

    data = {
        GOOGLE_CLIENT_ID      = var.google_client_id
        GOOGLE_CLIENT_SECRET  = var.google_client_secret
        GOOGLE_CLIENT_DOMAINS = var.google_client_domains
    }
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