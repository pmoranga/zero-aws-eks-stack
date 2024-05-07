
module "logging_cloudwatch" {
  count        = var.logging_type == "cloudwatch" ? 1 : 0
  source       = "./logging/cloudwatch"
  environment  = var.environment
  region       = var.region
  cluster_name = var.cluster_name
}

module "logging_kibana" {
  count                = var.logging_type == "kibana" ? 1 : 0
  source               = "./logging/kibana"
  environment          = var.environment
  region               = var.region
  elasticsearch_domain = "${var.project}-${var.environment}-logging"
  elasticsearch_url    = var.logging_elasticsearch_url
  domain_name          = var.domain_name
}

module "metrics_prometheus" {
  count                       = var.metrics_type == "prometheus" ? 1 : 0
  source                      = "./metrics/prometheus"
  project                     = var.project
  environment                 = var.environment
  region                      = var.region
  cluster_name                = var.cluster_name
  grafana_domain              = var.grafana_domain
  elasticsearch_domain        = "${var.project}-${var.environment}-logging"
  elasticsearch_url           = var.logging_elasticsearch_url
  grafana_plugins             = var.grafana_plugins
  use_oauth2_proxy            = var.oauth2_proxy_install
  grafana_externally          = var.metrics_open_grafana_externally
  grafana_ingress_annotations = var.grafana_ingress_annotations
  metrics_collect_labels      = var.metrics_collect_labels
}

module "ingress" {
  source  = "commitdev/zero/aws//modules/kubernetes/ingress_nginx"
  version = "0.6.6"

  chart_version = "4.10.0"
  # chart_version = "4.9.1"
  replica_count  = var.nginx_ingress_replicas
  enable_metrics = var.metrics_type == "prometheus"

  additional_configmap_options = merge(
    {
      "use-gzip" : "true",
      "compute-full-forwarded-for" : "true",
      "enable-real-ip" : "true",
      "allow-snippet-annotations" : "true"
  }, local.oauth2_nginx_ingress_options)
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.project
  }
}


# Enable prefix delegation - this will enable many more IPs to be allocated per-node.
# See https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
resource "null_resource" "enable_prefix_delegation" {

  # This is a static value so it won't be run multiple times.
  # If these env vars get removed somehow, this value can just be incremented.
  triggers = {
    "version" = "1"
  }

  provisioner "local-exec" {
    command = "kubectl set env daemonset aws-node ${local.k8s_exec_context} -n kube-system ENABLE_PREFIX_DELEGATION=true WARM_PREFIX_TARGET=1"
  }

  depends_on = [
    kubernetes_config_map.aws_auth,
    aws_iam_role.access_assumerole,
    kubernetes_cluster_role_binding.access_role,
    kubectl_manifest.cert_manager_http_issuer, # This is to prevent a race condition when trying to use an IAM role that was just created
  ]
}
