# Terraform for Development Cluster
This repository contains the terraform module for provisioning our development cluster for SCAUT v2. This cluster is built around AWS technologies, using EKS to deploy our code and run system-wide development services.

## Pre-requisites
To provision clusters with this repository, you will need the following tools:

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [AWS IAM Authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)
- [Terraform](https://www.terraform.io/downloads.html)

With these tools installed, you will need to set them up with your AWS IAM credentials. [Login via IAM](https://vitalbeats-engineering.signin.aws.amazon.com/console) and navigate to your user credentials. The URL will be something like [https://console.aws.amazon.com/iam/home?region=eu-west-1#/users/user.name@vitalbeats.com?section=security_credentials](https://console.aws.amazon.com/iam/home?region=eu-west-1#/users). Create a new access key (you are only allowed 2 active at a time), and record the access key ID and secret, you will need this for the next step. Then open a terminal and run:

```
$ aws configure
AWS Access Key ID [None]: Example_Access_ID
AWS Secret Access Key [None]: Example_Access_Secret
Default region name [None]: eu-west-1
Default output format [None]: json
```

With this configured, you can now access AWS. You can confirm this by running `aws sts get-caller-identity`. It will return you a JSON result which contains your IAM username in the ARN field.

With this repository checked out, you will need to first initialise and download terraform providers. This can be done by running `terraform init`.

## Access
This repository assumes usage of an [S3 backend](https://www.terraform.io/docs/backends/types/s3.html). To use this backend, your IAM user will need the `TerraformEKSDevBackend` attached to it to use this backend. In addition, terraform will expect you to specify the AWS region where operations should be executed. You can do this by defining the AWS default region environment variable `export AWS_DEFAULT_REGION=eu-west-1`. Vital Beats operates in EU West 1 (Ireland) region.

## Running
To run this repository, you first must set up some secrets and credentials for the cluster to use. Create `terraform.tfvars` based upon `terraform.tfvars.example`. Once done, you can run the repository with `terraform plan` or `terraform apply` as usual.

## Common Operations
There are various services in the cluster which need upgrading. Various scripts exist to make this easier.

### Jenkins
Run `./update-jenkins.sh <version>` which will upgrade Jenkins and update the master branch to reflect the new version.