locals {
    pull_request_postgresql_secret = {
      POSTGRESQL_DATABASE       = var.pull_request_postgresql_database_name,
      POSTGRESQL_USER           = var.pull_request_postgresql_database_username,
      POSTGRESQL_PASSWORD       = var.pull_request_postgresql_database_password,
      POSTGRESQL_ADMIN_PASSWORD = var.pull_request_postgresql_database_admin_password,
    }

    pull_request_jwt_secret = {
        JWT_SECRET_KEY = var.pull_request_jwt_key
    }

    pull_request_gateway_api_secret = {
        SMS_GATEWAY_API_KEY = var.pull_request_gateway_api_key
    }

    pull_request_iris_erlang_secret = {
        ERLANG_COOKIE = var.pull_request_erlang_cookie_iris
    }
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

resource "aws_iam_policy" "pull-request-jwt-secret" {
    name        = "scaut-v2-dev-PullRequestJWTSecrets"
    description = "Secrets for JWT signing in pull requests"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/pull-request/jwt*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "pull-request-jwt-secret" {
  name        = "scaut-v2-dev-secrets-manager-pull-request-jwt"
  description = "Allows the Kubernetes Secrets Manager to read secrets for JWT signing in pull requests"
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

resource "aws_iam_role_policy_attachment" "pull-request-jwt-secret" {
  role       = aws_iam_role.pull-request-jwt-secret.name
  policy_arn = aws_iam_policy.pull-request-jwt-secret.arn
}

resource "aws_secretsmanager_secret" "pull-request-jwt-secret" {
  name        = "scaut-v2-dev/pull-request/jwt"
  description = "Secrets for JWT signing in pull requests"
}

resource "aws_secretsmanager_secret_version" "pull-request-jwt-secret" {
  secret_id     = aws_secretsmanager_secret.pull-request-jwt-secret.id
  secret_string = jsonencode(local.pull_request_jwt_secret)
}

resource "aws_iam_policy" "pull-request-gateway-api-secret" {
    name        = "scaut-v2-dev-PullRequestGatewayAPISecrets"
    description = "Secrets for gateway-api usage in pull requests"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/pull-request/gateway-api*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "pull-request-gateway-api-secret" {
  name        = "scaut-v2-dev-secrets-manager-pull-request-gateway-api"
  description = "Allows the Kubernetes Secrets Manager to read secrets for gateway-api usage in pull requests"
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

resource "aws_iam_role_policy_attachment" "pull-request-gateway-api-secret" {
  role       = aws_iam_role.pull-request-gateway-api-secret.name
  policy_arn = aws_iam_policy.pull-request-gateway-api-secret.arn
}

resource "aws_secretsmanager_secret" "pull-request-gateway-api-secret" {
  name        = "scaut-v2-dev/pull-request/gateway-api"
  description = "Secrets for gateway-api usage in pull requests"
}

resource "aws_secretsmanager_secret_version" "pull-request-gateway-api-secret" {
  secret_id     = aws_secretsmanager_secret.pull-request-gateway-api-secret.id
  secret_string = jsonencode(local.pull_request_gateway_api_secret)
}

resource "aws_iam_policy" "pull-request-iris-erlang-secret" {
    name        = "scaut-v2-dev-PullRequestIrisErlangSecrets"
    description = "Secrets for iris-erlang usage in pull requests"
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
        "arn:aws:secretsmanager:eu-west-1:454089853750:secret:scaut-v2-dev/pull-request/iris-erlang*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "pull-request-iris-erlang-secret" {
  name        = "scaut-v2-dev-secrets-manager-pull-request-iris-erlang"
  description = "Allows the Kubernetes Secrets Manager to read secrets for iris-erlang usage in pull requests"
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

resource "aws_iam_role_policy_attachment" "pull-request-iris-erlang-secret" {
  role       = aws_iam_role.pull-request-iris-erlang-secret.name
  policy_arn = aws_iam_policy.pull-request-iris-erlang-secret.arn
}

resource "aws_secretsmanager_secret" "pull-request-iris-erlang-secret" {
  name        = "scaut-v2-dev/pull-request/iris-erlang"
  description = "Secrets for iris-erlang usage in pull requests"
}

resource "aws_secretsmanager_secret_version" "pull-request-iris-erlang-secret" {
  secret_id     = aws_secretsmanager_secret.pull-request-iris-erlang-secret.id
  secret_string = jsonencode(local.pull_request_iris_erlang_secret)
}