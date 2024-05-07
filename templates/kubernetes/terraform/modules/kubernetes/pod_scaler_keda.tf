locals {
  keda_namespace = "kube-system"
}

## https://artifacthub.io/packages/helm/kedacore/keda

resource "helm_release" "keda" {
  count = var.keda_enabled ? 1 : 0

  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.13.2"
  namespace  = local.keda_namespace

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }
  set {
    name  = "rbac.create"
    value = true
  }
  set {
    type  = "string"
    name  = "podIdentity.aws.irsa.roleArn"
    value = module.iam_assumable_role_keda[0].this_iam_role_arn
  }
  set {
    name = "podIdentity.aws.irsa.enabled"
    value = true
  }
  set {
    name = "logging.metricServer.level"
    value = 4
  }
  set {
    name = "logging.metricServer.stderrthreshold"
    value = "4"
  }
  set {
    name = "prometheus.metricServer.enabled"
    value = true
  }
  set {
    name = "prometheus.metricServer.podMonitor.enabled"
    value = true
  }
}



# Create a role using oidc to map service accounts
module "iam_assumable_role_keda" {
  count = var.keda_enabled ? 1 : 0

  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> v3.12.0"
  create_role                   = true
  role_name                     = "${var.project}-k8s-${var.environment}-keda"
  provider_url                  = replace(data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer, "https://", "")
  role_policy_arns              = [aws_iam_policy.keda[0].arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.keda_namespace}:keda-operator"]
}

resource "aws_iam_policy" "keda" {
  count = var.keda_enabled ? 1 : 0

  name_prefix = "keda"
  description = "EKS keda policy for cluster ${var.cluster_name}"
  policy      = data.aws_iam_policy_document.keda_policy_doc.json
}

data "aws_iam_policy_document" "keda_policy_doc" {
  statement {
    sid    = "cloudwatch"
    effect = "Allow"

    actions = [
      "cloudwatch:GetMetricData",
      "sqs:GetQueueAttributes"
    ]

    resources = ["*"]
  }

}
