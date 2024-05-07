locals {
  grafana_hostname = var.grafana_domain # "grafana.app.${var.grafana_domain}"

  grafana_ingress_ssl_enabled = contains(keys(var.grafana_ingress_annotations), "cert-manager.io/cluster-issuer")
  grafana_ingress_proto       = (local.grafana_ingress_ssl_enabled == true ? "https" : "http")
  grafana_ingress = var.grafana_externally == false ? [""] : [
    yamlencode({ "grafana" : {
      "ingress" : {
        "enabled" : true,
        "ingressClassName" : lookup(var.grafana_ingress_annotations, "kubernetes.io/ingress.class", "nginx"),
        "annotations" : merge(
          {
            "external-dns.alpha.kubernetes.io/hostname" : local.grafana_hostname
          },
          var.grafana_ingress_annotations,
        ),
        "hosts" : [local.grafana_hostname]
        "tls" : local.grafana_ingress_ssl_enabled ? [
          {
            "secretName" : "grafana-ssl-secret",
            "hosts" : [
              local.grafana_hostname
            ]
          }
        ] : []
      }
  } })]
  grafana_plugins = [yamlencode({
    "grafana" : { "plugins" : concat(var.grafana_plugins, ["grafana-opensearch-datasource"]) }
  })]

  elasticsearch_url = var.elasticsearch_domain == "" ? "" : ( var.elasticsearch_url == "" ? "https://${data.aws_elasticsearch_domain.logging_cluster[0].endpoint}" : "https://${var.elasticsearch_url}" )
}


resource "kubernetes_namespace" "metrics" {
  metadata {
    name = "metrics"
    labels = {
      name = "metrics"
    }
  }
}

# Find the VPC
data "aws_vpc" "vpc" {
  tags = {
    Name : "${var.project}-${var.environment}-vpc"
  }
}

# Find the private subnets
data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.vpc.id
  tags = {
    environment : var.environment,
    visibility : "private",
  }
}

# Find the worker security group
data "aws_security_group" "eks_workers" {
  tags = {
    # Name : "${var.project}-${var.environment}-${var.region}-eks_worker_sg",
    Name : "${var.project}-${var.environment}-${var.region}-node",
  }
}

# Look up the elasticsearch cluster if supplied
data "aws_elasticsearch_domain" "logging_cluster" {
  count       = ( var.elasticsearch_domain != "" && var.elasticsearch_url == "" ) ? 1 : 0
  domain_name = var.elasticsearch_domain
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Install the prometheus stack, including prometheus-operator and grafana
resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  # version    = "55.11.0"
  version    = "56.21.4"

  namespace = kubernetes_namespace.metrics.metadata[0].name

  values = concat(
    [file("${path.module}/files/prometheus_operator_helm_values.yml")],
    var.grafana_externally ? local.grafana_ingress : [],
    local.grafana_plugins
  )

  set {
    name = "grafana.enabled"
    value =  ! var.grafana_disable
  }
  # Grafana dynamic config
  set {
    name  = "grafana.persistence.existingClaim"
    value = kubernetes_persistent_volume_claim_v1.grafana_nfs_pvc.metadata[0].name
  }

  set {
    name  = "grafana.persistence.size"
    value = kubernetes_persistent_volume_claim_v1.grafana_nfs_pvc.spec[0].resources[0].requests.storage
  }

  set {
    name  = "grafana.persistence.accessModes[0]"
    value = tolist(kubernetes_persistent_volume_claim_v1.grafana_nfs_pvc.spec[0].access_modes)[0]
  }

  set {
    name  = "grafana.adminPassword"
    value = var.project
  }

  set {
    name  = "grafana.env.GF_SERVER_ROOT_URL"
    type  = "string"
    value = var.grafana_domain == "" ? "http://grafana.metrics.svc.cluster.local/" : "${local.grafana_ingress_proto}://${local.grafana_hostname}/"
  }

  set {
    name  = "grafana.env.GF_SERVER_DOMAIN"
    type  = "string"
    value = var.grafana_domain == "" ? "grafana.metrics.svc.cluster.local" : local.grafana_hostname
  }
  set {
    name  = "grafana.env.GF_USERS_ALLOW_SIGN_UP"
    type  = "string"
    value = "false"
  }
  set {
    name = "grafana.env.GF_USERS_AUTO_ASSIGN_ORG"
    # type  = "string"
    value = "true"
  }
  set {
    name = "grafana.env.GF_USERS_AUTO_ASSIGN_ORG_ROLE"
    # type  = "string"
    value = "Editor"
  }
  set {
    name = "grafana.env.GF_AUTH_PROXY_ENABLED"
    # type  = "string"
    value = true
  }
  set {
    name = "grafana.env.GF_AUTH_PROXY_HEADER_NAME"
    # type  = "string"
    value = "X-AUTH-REQUEST-EMAIL"
  }

  set {
    name = "grafana.env.GF_AUTH_PROXY_HEADER_PROPERTY"
    # type  = "string"
    value = "email"
  }

  set {
    name = "grafana.env.GF_AUTH_PROXY_AUTO_SIGN_UP"
    # type  = "string"
    value = "true"
  }

  # Elasticsearch data source
  set {
    name  = "grafana.additionalDataSources[1].url"
    value = local.elasticsearch_url
  }
  set {
    name  = "grafana.additionalDataSources[2].url"
    value = local.elasticsearch_url
  }
  set {
    name  = "grafana.additionalDataSources[3].url"
    value = local.elasticsearch_url
  }
  # Cloudwatch data source
  set {
    name  = "grafana.additionalDataSources[0].jsonData.defaultRegion"
    value = var.region
  }

  set {
    name  = "grafana.additionalDataSources[0].jsonData.assumeRoleArn"
    value = ""
  }


  # Use the IRSA role we create below in the service account to give grafana access to Cloudwatch
  set {
    name  = "grafana.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_irsa.this_iam_role_arn
  }

  # Prometheus dynamic config
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "${var.prometheus_retention_days}d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.volumeName"
    value = kubernetes_persistent_volume.prometheus_nfs_pv.metadata[0].name
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = tolist(kubernetes_persistent_volume.prometheus_nfs_pv.spec[0].access_modes)[0]
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = kubernetes_persistent_volume.prometheus_nfs_pv.spec[0].storage_class_name
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = kubernetes_persistent_volume.prometheus_nfs_pv.spec[0].capacity.storage
  }

  set_list {
    name = "kube-state-metrics.metricLabelsAllowlist"
    value =  [for k, v in var.metrics_collect_labels : "${k}=[${join(",", v)}]"]
  } 
  #     "nodes=[size,node.kubernetes.io/instance-type,topology.kubernetes.io/zone]",
  #   ])
  # }

  # set {
  #   name  = "grafana.ini"
  #   value = <<EOF

  # %{if var.use_oauth2_proxy == true}

  # # [users]
  # # allow_sign_up = false
  # # auto_assign_org = true
  # # auto_assign_org_role = Editor

  # [auth.proxy]
  # # Defaults to false, but set to true to enable this feature
  # enabled = true
  # # HTTP Header name that will contain the username or email
  # header_name = X-AUTH-REQUEST-EMAIL
  # # HTTP Header property, defaults to `username` but can also be `email`
  # header_property = email
  # # Set to `true` to enable auto sign up of users who do not exist in Grafana DB. Defaults to `true`.
  # auto_sign_up = true
  # # Define cache time to live in minutes
  # # If combined with Grafana LDAP integration it is also the sync interval
  # sync_ttl = 60
  # # Optionally define more headers to sync other user attributes
  # # Example `headers = Name:X-WEBAUTH-NAME Role:X-WEBAUTH-ROLE Email:X-WEBAUTH-EMAIL Groups:X-WEBAUTH-GROUPS`
  # headers = 
  # # Non-ASCII strings in header values are encoded using quoted-printable encoding
  # ;headers_encoded = false
  # # Check out docs on this for more details on the below setting
  # ;enable_login_token = false

  # %{endif~}
  # EOF

  #  }
}
