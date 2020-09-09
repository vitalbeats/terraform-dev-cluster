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

provider "random" {
  version = "~> 2.2"
}

module "cluster" {
  source  = "vitalbeats/cluster/eks"
  version = "0.1.0-beta.39"

  cluster-name       = "scaut-v2-dev"
  ec2-ssh-key        = "stephen.badger"
  enable-letsencrypt = true
  enable-datadog     = true
  datadog-api-key    = var.datadog_api_key
  datadog-app-key    = var.datadog_app_key
  letsencrypt-email  = "engineering@vitalbeats.com"
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

    pull_request_service_secret = {
      webhook = var.pull_request_service_secret
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

resource "aws_iam_policy" "jenkins-params" {
    name        = "scaut-v2-dev-JenkinsParams"
    description = "Parameters used by Jenkins in development"
    path        = "/scaut-v2-dev/"

    policy =<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": [
        "arn:aws:ssm:eu-west-1:454089853750:parameter/scaut-v2-dev/openshift-build/*"
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

resource "aws_iam_role_policy_attachment" "jenkins-params" {
  role       = aws_iam_role.jenkins-secrets.name
  policy_arn = aws_iam_policy.jenkins-params.arn
}

resource "aws_secretsmanager_secret" "jenkins-google-oauth" {
    name        = "scaut-v2-dev/openshift-build/jenkins-google-oauth"
    description = "Allows GSuite login for Jenkins"
}

resource "aws_secretsmanager_secret_version" "jenkins-google-oauth" {
    secret_id     = aws_secretsmanager_secret.jenkins-google-oauth.id
    secret_string = jsonencode(local.google_oauth)
}

resource "aws_ssm_parameter" "jenkins-ssh-privatekey" {
    name        = "/scaut-v2-dev/openshift-build/jenkins-ssh-privatekey"
    description = "SSH key for Git in Jenkins"
    type        = "SecureString"
    value       =  file("${path.module}/input/ssh-privatekey")
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

resource "aws_iam_policy" "pypi-auth-secrets" {
    name        = "scaut-v2-dev-PyPIAuthSecrets"
    description = "Secrets used to control who has access to PyPI"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/openshift-build/pypi-auth*"
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

resource "aws_iam_role" "pypi-auth-secrets" {
  name        = "scaut-v2-dev-secrets-manager-pypi"
  description = "Allows the Kubernetes Secrets Manager to read PyPI Server auth secrets"
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

resource "aws_iam_role_policy_attachment" "pypi-auth-secrets" {
  role       = aws_iam_role.pypi-auth-secrets.name
  policy_arn = aws_iam_policy.pypi-auth-secrets.arn
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

data "kustomization" "pypiserver" {
  path = "pypiserver"
}

resource "kustomization_resource" "pypiserver" {
  for_each = data.kustomization.pypiserver.ids

  manifest = data.kustomization.pypiserver.manifests[each.value]
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

resource "aws_iam_policy" "pull-request-service-secrets" {
    name        = "scaut-v2-dev-PullRequestServiceSecrets"
    description = "Secrets used by the pull-request-service"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/pull-request-service/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy" "pull-request-service-internal-registry" {
    name        = "scaut-v2-dev-PullRequestServiceInternalRegistry"
    description = "Secrets used by the pull-request-service for pulling internal registry images"
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

resource "aws_iam_role" "pull-request-service-secrets" {
  name        = "scaut-v2-dev-secrets-manager-pull-request-service"
  description = "Allows the Kubernetes Secrets Manager to read pull-request-service secrets"
  path        = "/secrets/scaut-v2-dev/pull-request-service/"

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

resource "aws_iam_role_policy_attachment" "pull-request-service-secrets" {
  role       = aws_iam_role.pull-request-service-secrets.name
  policy_arn = aws_iam_policy.pull-request-service-secrets.arn
}

resource "aws_iam_role_policy_attachment" "pull-request-service-internal-registry" {
  role       = aws_iam_role.pull-request-service-secrets.name
  policy_arn = aws_iam_policy.pull-request-service-internal-registry.arn
}

resource "aws_secretsmanager_secret" "pull-request-service-secret" {
  name        = "scaut-v2-dev/pull-request-service/pull-request-service-secret"
  description = "Credentials for running a docker registry"
}

resource "aws_secretsmanager_secret_version" "pull-request-service-secret" {
  secret_id     = aws_secretsmanager_secret.pull-request-service-secret.id
  secret_string = jsonencode(local.pull_request_service_secret)
}

resource "kubernetes_namespace" "pull-request-service" {
    metadata {
        name = "pull-request-service"

        annotations = {
          "iam.amazonaws.com/permitted" = "arn:aws:iam::454089853750:role/secrets/scaut-v2-dev/pull-request-service/scaut-v2-dev-secrets-manager-pull-request-service"
        }
    }
}

resource "kubernetes_namespace" "nextcloud" {
    metadata {
        name = "nextcloud"

        annotations = {
          "iam.amazonaws.com/permitted" = "arn:aws:iam::454089853750:role/secrets/scaut-v2-dev/nextcloud/scaut-v2-dev-secrets-manager-nextcloud"
        }
    }
}

data "kustomization" "nextcloud" {
  path = "nextcloud"
}

resource "kustomization_resource" "nextcloud" {
  for_each = data.kustomization.nextcloud.ids

  manifest = data.kustomization.nextcloud.manifests[each.value]
}

resource "random_string" "nextcloud-mysql-root-password" {
    length = 16
    special = false
}

resource "random_string" "nextcloud-mysql-user" {
    length = 16
    special = false
}

resource "random_string" "nextcloud-mysql-password" {
    length = 16
    special = false
}

resource "random_string" "nextcloud-admin-password" {
    length = 24
    special = false
}

resource "aws_secretsmanager_secret" "nextcloud-mysql-root" {
  name        = "scaut-v2-dev/nextcloud/nextcloud-mysql-root"
  description = "Credentials for the MySQL root password for NEXTCloud"
}

resource "aws_secretsmanager_secret_version" "nextcloud-mysql-root" {
  secret_id     = aws_secretsmanager_secret.nextcloud-mysql-root.id
  secret_string = jsonencode({
    MYSQL_ROOT_PASSWORD = random_string.nextcloud-mysql-root-password.result
  })
}

resource "aws_secretsmanager_secret" "nextcloud-mysql-user" {
  name        = "scaut-v2-dev/nextcloud/nextcloud-mysql-user"
  description = "Credentials for the MySQL user for NEXTCloud"
}

resource "aws_secretsmanager_secret_version" "nextcloud-mysql-user" {
  secret_id     = aws_secretsmanager_secret.nextcloud-mysql-user.id
  secret_string = jsonencode({ 
    MYSQL_PASSWORD = random_string.nextcloud-mysql-password.result,
    MYSQL_USER     = random_string.nextcloud-mysql-user.result,
    MYSQL_DATABASE = "nextcloud"
  })
}

resource "aws_secretsmanager_secret" "nextcloud-admin" {
  name        = "scaut-v2-dev/nextcloud/nextcloud-admin"
  description = "Credentials for the Admin user for NEXTCloud"
}

resource "aws_secretsmanager_secret_version" "nextcloud-admin" {
  secret_id     = aws_secretsmanager_secret.nextcloud-admin.id
  secret_string = jsonencode({ 
    NEXTCLOUD_ADMIN_USER     = "nextcloud",
    NEXTCLOUD_ADMIN_PASSWORD = random_string.nextcloud-admin-password.result,
  })
}

resource "aws_iam_policy" "nextcloud-secrets" {
    name        = "scaut-v2-dev-NEXTCloud"
    description = "Allows the Kubernetes Secrets Manager to read nextcloud secrets"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/nextcloud/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "nextcloud-secrets" {
  name        = "scaut-v2-dev-secrets-manager-nextcloud"
  description = "Allows the Kubernetes Secrets Manager to read nextcloud secrets"
  path        = "/secrets/scaut-v2-dev/nextcloud/"

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

resource "aws_iam_role_policy_attachment" "nextcloud-secrets" {
  role       = aws_iam_role.nextcloud-secrets.name
  policy_arn = aws_iam_policy.nextcloud-secrets.arn
}

resource "aws_iam_policy" "push-ecr-images" {
  policy =<<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:ListTagsForResource",
                "ecr:UploadLayerPart",
                "ecr:BatchDeleteImage",
                "ecr:ListImages",
                "ecr:PutImage",
                "ecr:UntagResource",
                "ecr:BatchGetImage",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeImages",
                "ecr:TagResource",
                "ecr:DescribeRepositories",
                "ecr:InitiateLayerUpload",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Resource": "arn:aws:ecr:eu-west-1:454089853750:repository/*"
        },
        {
            "Effect": "Allow",
            "Action": "ecr:GetAuthorizationToken",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "jenkins" {
  path        = "/scaut-v2-dev/"
  name        = "scaut-v2-dev-jenkins"
  description = "Allows Jenkins to interact with AWS"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.cluster.cluster_oidc_provider}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${module.cluster.cluster_oidc_provider}:sub": "system:serviceaccount:jenkins:jenkins"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "push-ecr-images" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.push-ecr-images.arn
}
