# helm repo add uptime-kuma https://dirsigler.github.io/uptime-kuma-helm
# helm install my-uptime-kuma uptime-kuma/uptime-kuma --version 2.14.1



locals {
  uptimekuma_namespace = "uptimekuma"
  uptimekuma_domain    = "uptime.${var.domain_name}"

}

resource "kubernetes_namespace" "uptimekuma" {
  count = var.uptimekuma_enabled ? 1 : 0

  metadata {
    annotations = {
      name = local.uptimekuma_namespace
    }

    labels = {
      mylabel = local.uptimekuma_namespace
    }

    name = local.uptimekuma_namespace
  }
}

resource "helm_release" "uptimekuma" {
  count = var.uptimekuma_enabled ? 1 : 0

  name       = "uptimekuma"
  repository = "https://dirsigler.github.io/uptime-kuma-helm"
  chart      = "uptime-kuma"
  version    = "2.18.0"
  namespace  = kubernetes_namespace.uptimekuma[0].metadata[0].name
  depends_on = [
    kubernetes_namespace.uptimekuma,
  ]


  #   values = [yamlencode(var.uptimekuma_helm_values)]

  values = [yamlencode({
    # "image" : {
    #     "repository": "k8s.gcr.io/echoserver",
    #     "tag" : 1.10
    # }
    "ingress" : {
      "enabled" : true,
      "annotations" : {
        "kubernetes.io/ingress.class" : "nginx",
        "cert-manager.io/cluster-issuer" : "letsencrypt-prod",
        "cert-manager.io/cluster-issuer" : "clusterissuer-letsencrypt-production",
        "external-dns.alpha.kubernetes.io/hostname" : local.uptimekuma_domain
      },
      "hosts" : [{
        "host" : local.uptimekuma_domain,
        "paths" : [
          {
            "path" : "/"
            "pathType" : "ImplementationSpecific"
          }
        ]
      }],
      "tls" : [
        {
          "secretName" : "${local.uptimekuma_namespace}-secret",
          "hosts" : [
            local.uptimekuma_domain
          ]
        }
      ]
    }
    "resources" : {
      "limits" : {
        "memory" : "2Gi"
        "cpu" : "2000m",

      },
      "requests" : {
        "cpu" : "200m",
        "memory" : "512Mi"
      }
    }
  })]
}


variable "uptimekuma_enabled" {
  description = "Enable the Uptime Kuma (https://github.com/louislam/uptime-kuma)"
  default     = false
  type        = bool
}

# variable "uptimekumar_helm_values" {
#   description = "The values to be passed to helm for chart https://artifacthub.io/packages/helm/uptime-kuma/uptime-kuma"
#   default = {
#     # "replicaCount" : 1
#   }
# }
