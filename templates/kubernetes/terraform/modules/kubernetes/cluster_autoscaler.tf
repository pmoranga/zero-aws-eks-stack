locals {
  cluster_autoscaler_namespace = "kube-system"
}


resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.36.0"
  namespace  = local.cluster_autoscaler_namespace

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
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_cluster_autoscaler.this_iam_role_arn
  }
  set {
    name  = "awsRegion"
    value = var.region
  }

  values = [yamlencode( merge({
    "extraArgs" : {
      "logtostderr" : true,
      "stderrthreshold" : "info",
      "v" : 4,
      "skip-nodes-with-local-storage" : false,
      "scale-down-unneeded-time" : "3m",
      "expander" :  ( length(var.autoscaler_expander_priorities) == 0 ) ? "random" : "priority,random",
    } },
    length(var.autoscaler_expander_priorities) == 0 ? {} : { "expanderPriorities": var.autoscaler_expander_priorities }
  ))]
}

# Create a role using oidc to map service accounts
module "iam_assumable_role_cluster_autoscaler" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> v3.12.0"
  create_role                   = true
  role_name                     = "${var.project}-k8s-${var.environment}-cluster-autoscaler"
  provider_url                  = replace(data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_autoscaler.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.cluster_autoscaler_namespace}:cluster-autoscaler-aws-cluster-autoscaler"]
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name_prefix = "cluster-autoscaler"
  description = "EKS cluster-autoscaler policy for cluster ${var.cluster_name}"
  policy      = data.aws_iam_policy_document.cluster_autoscaler_policy_doc.json
}

data "aws_iam_policy_document" "cluster_autoscaler_policy_doc" {
  statement {
    sid    = "eksWorkerAutoscalingAll"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
      "eks:DescribeNodegroup",
      "ec2:DescribeInstanceTypes"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "eksWorkerAutoscalingOwn"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}
