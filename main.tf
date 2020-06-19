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

data "aws_caller_identity" "current" {}

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

    pypi_config = {
      "auth.toml"   = "${file("${path.module}/input/auth.toml")}"
      "config.toml" = "${file("${path.module}/input/config.toml")}"
      password      = var.pypi_password
      username      = var.pypi_username
    }

    docker_registry_secret = {
      htpasswd       = "${file("${path.module}/input/registry-htpasswd")}"
      haSharedSecret = var.registry_ha_secret
    }

    docker_registry_config = {
      ".dockerconfigjson" = "${file("${path.module}/input/registry-config.json")}"
    }

    pull_request_postgresql_secret = {
      POSTGRESQL_DATABASE       = var.pull_request_postgresql_database_name,
      POSTGRESQL_USER           = var.pull_request_postgresql_database_username,
      POSTGRESQL_PASSWORD       = var.pull_request_postgresql_database_password,
      POSTGRESQL_ADMIN_PASSWORD = var.pull_request_postgresql_database_admin_password,
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

resource "aws_secretsmanager_secret" "jenkins-ssh-privatekey" {
    name        = "scaut-v2-dev/openshift-build/jenkins-ssh-privatekey"
    description = "SSH key for Git in Jenkins"
}

resource "aws_secretsmanager_secret_version" "jenkins-ssh-privatekey" {
    secret_id     = aws_secretsmanager_secret.jenkins-ssh-privatekey.id
    secret_string = jsonencode("${file("${path.module}/input/ssh-privatekey")}")
}

resource "aws_secretsmanager_secret_version" "jenkins-pypi-config" {
    secret_id     = aws_secretsmanager_secret.jenkins-pypi-config.id
    secret_string = jsonencode(local.pypi_config)
}

resource "aws_secretsmanager_secret" "jenkins-pypi-config" {
    name        = "scaut-v2-dev/openshift-build/jenkins-pypi-config"
    description = "PyPI config for Jenkins"
}

resource "aws_iam_policy" "registry-secrets" {
    name        = "scaut-v2-dev-RegistrySecrets"
    description = "Secrets used by docker registry in development"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/registry/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "registry-config" {
    name        = "scaut-v2-dev-RegistryConfig"
    description = "Secrets for the registry config in development"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/docker-registry-config*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "registry-secrets" {
  name        = "scaut-v2-dev-secrets-manager-registry"
  description = "Allows the Kubernetes Secrets Manager to read docker registry secrets"
  path        = "/secrets/scaut-v2-dev/registry/"

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

resource "aws_iam_role" "registry-config" {
  name        = "scaut-v2-dev-secrets-manager-registry-config"
  description = "Allows the Kubernetes Secrets Manager to read docker registry config"
  path        = "/secrets/scaut-v2-dev/"

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

resource "aws_iam_role_policy_attachment" "registry-secrets" {
  role       = aws_iam_role.registry-secrets.name
  policy_arn = aws_iam_policy.registry-secrets.arn
}

resource "aws_iam_role_policy_attachment" "registry-config" {
  role       = aws_iam_role.registry-config.name
  policy_arn = aws_iam_policy.registry-config.arn
}

resource "aws_secretsmanager_secret" "docker-registry-secret" {
  name        = "scaut-v2-dev/registry/docker-registry-secret"
  description = "Credentials for running a docker registry"
}

resource "aws_secretsmanager_secret" "docker-registry-config" {
  name        = "scaut-v2-dev/docker-registry-config"
  description = "Credentials for connecting to the internal docker registry"
}

resource "aws_secretsmanager_secret_version" "docker-registry-config" {
  secret_id     = aws_secretsmanager_secret.docker-registry-config.id
  secret_string = jsonencode(local.docker_registry_config)
}

resource "aws_secretsmanager_secret_version" "docker-registry-secret" {
  secret_id     = aws_secretsmanager_secret.docker-registry-secret.id
  secret_string = jsonencode(local.docker_registry_secret)
}

data "kustomization" "jenkins" {
  path = "jenkins"
}

resource "kustomization_resource" "jenkins" {
  for_each = data.kustomization.jenkins.ids

  manifest = data.kustomization.jenkins.manifests[each.value]
}

resource "kubernetes_namespace" "registry" {
    metadata {
        name = "registry"
    }
}

data "kustomization" "registry" {
  path = "registry"
}

resource "kustomization_resource" "registry" {
  for_each = data.kustomization.registry.ids

  manifest = data.kustomization.registry.manifests[each.value]
}

resource "aws_iam_policy" "pull-request-postgresql-secret" {
    name        = "scaut-v2-dev-PullRequestPostgreSQLSecrets"
    description = "Secrets for PostgreSQL databases in pull requests"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/pull-request/postgresql*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "pull-request-postgresql-secret" {
  name        = "scaut-v2-dev-secrets-manager-pull-request-postgresql"
  description = "Allows the Kubernetes Secrets Manager to read secrets for PostgreSQL databases in pull requests"
  path        = "/secrets/scaut-v2-dev/pull-request/"

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

resource "aws_iam_role_policy_attachment" "pull-request-postgresql-secret" {
  role       = aws_iam_role.pull-request-postgresql-secret.name
  policy_arn = aws_iam_policy.pull-request-postgresql-secret.arn
}

resource "aws_secretsmanager_secret" "pull-request-postgresql-secret" {
  name        = "scaut-v2-dev/pull-request/postgresql"
  description = "Secrets for PostgreSQL databases in pull requests"
}

resource "aws_secretsmanager_secret_version" "pull-request-postgresql-secret" {
  secret_id     = aws_secretsmanager_secret.pull-request-postgresql-secret.id
  secret_string = jsonencode(local.pull_request_postgresql_secret)
}