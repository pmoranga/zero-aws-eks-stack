
locals {
  # echoheader_provider = "github"
  echoheader_domain    = "echo.${var.domain_name}"
  echoheader_namespace = "echoheader"

}


resource "kubernetes_namespace" "echoheader" {
  count = var.echoheader_enabled ? 1 : 0

  metadata {
    annotations = {
      name = local.echoheader_namespace
    }

    labels = {
      mylabel = local.echoheader_namespace
    }

    name = local.echoheader_namespace
  }
}

resource "helm_release" "echoheader_proxy" {
  count = var.echoheader_enabled ? 1 : 0

  name       = "echo-server"
  repository = "https://ealenn.github.io/charts"
  chart      = "echo-server"
  version    = "0.5.0"
  namespace  = kubernetes_namespace.echoheader[0].metadata[0].name
  depends_on = [
    kubernetes_namespace.echoheader,
  ]

  values = [yamlencode({
    "ingress" : {
      "enabled" : true,
      "annotations" : {
        "kubernetes.io/ingress.class" : "nginx",
        "cert-manager.io/cluster-issuer" : "letsencrypt-prod",
        "cert-manager.io/cluster-issuer" : "clusterissuer-letsencrypt-production",
        "external-dns.alpha.kubernetes.io/hostname" : local.echoheader_domain

      },
      "hosts" : [{
        "host" : local.echoheader_domain,
        "paths" : ["/"]
      }],
      "tls" : [
        {
          "secretName" : "${local.echoheader_namespace}-secret",
          "hosts" : [
            local.echoheader_domain
          ]
        }
      ]
    }
  })]
}
