terraform {
  backend "s3" {
    bucket         = "<% .Name %>-staging-terraform-state"
    key            = "infrastructure/terraform/environments/staging/kubernetes"
    encrypt        = true
    region         = "<% .Region %>"
    dynamodb_table = "<% .Name %>-staging-terraform-state-locks"
  }
}

provider "aws" {
  region  = "<% .Region %>"
}

# Provision kubernetes resources required to run services/applications
module "kubernetes" {
  source = "../../modules/kubernetes"

  environment = "staging"
  region      = "<% .Region %>"

  # Authenticate with the EKS cluster via the cluster id
  cluster_name = "<% .Name %>-staging-cluster"

  # Assume-role policy used by monitoring fluentd daemonset
  assume_role_policy = data.aws_iam_policy_document.assumerole_root_policy.json

  external_dns_zone = "<% .StagingHost %>"
  external_dns_owner_id = "<% GenerateUUID %>" # randomly generated ID
  external_dns_assume_roles = [ "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/k8s-<% .Name %>-staging-<% .Region %>-workers" ]
}

# Data sources for EKS IAM
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assumerole_root_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}
