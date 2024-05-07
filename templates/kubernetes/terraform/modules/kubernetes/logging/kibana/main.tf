locals {
  logs_domain = "logs.${var.domain_name}"
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
    labels = {
      name = "logging"
    }
  }
}


# Utility dns record for people using vpn
resource "kubernetes_service" "elasticsearch" {
  metadata {
    namespace = kubernetes_namespace.logging.metadata[0].name
    name      = "kibana"
  }
  spec {
    type          = "ExternalName"
    external_name = var.elasticsearch_url == "" ? data.aws_elasticsearch_domain.logging_cluster[0].endpoint : var.elasticsearch_url
  }
}
# # Kibana ingress - Allows us to modify the path, but proxies out to elasticsearch
# resource "kubernetes_ingress_v1" "kibana_ingress" {
#   metadata {
#     name      = "kibana"
#     namespace = "logging"
#     annotations = {
#       # "kubernetes.io/ingress.class"                    = "nginx-internal"
#       "nginx.ingress.kubernetes.io/proxy-body-size"    = "32m"
#       "nginx.ingress.kubernetes.io/rewrite-target"     = "/_dashboards/app/management/$1"
#       "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"

#       "kubernetes.io/ingress.class" : "nginx",
#       "cert-manager.io/cluster-issuer" : "letsencrypt-prod",
#       "cert-manager.io/cluster-issuer" : "clusterissuer-letsencrypt-production",
#       "external-dns.alpha.kubernetes.io/hostname" : local.logs_domain
#       "nginx.ingress.kubernetes.io/configuration-snippet": <<EOF
# more_set_headers "X-Frame-Options: Deny";
# more_set_headers "Content-Security-Policy: default-src 'self' 'unsafe-inline' *; script-src 'unsafe-inline' *";
# more_set_headers "X-Xss-Protection: 1; mode=block";
# EOF
# # more_clear_headers "Cache-Control";
# # more_set_headers "Cache-Control: must-revalidate";  
# # more_set_headers "X-Content-Type-Options: nosniff";
# # l5d-dst-override
#     }
#   }

#   spec {
#     # # default_backend {
#     # #   service {
#     # #     name = "elasticsearch"
#     # #     port {
#     # #       number = 80
#     # #     }
#     # #   }
#     # # }
#     rule {
#       host = local.logs_domain

#       http {
#         path {
#           path = "/(.*)"
#           backend {
#             service {

#               name = kubernetes_service.elasticsearch.metadata[0].name
#               port {
#                 number = 80
#               }
#             }
#           }
#         }

#         path {
#           path = "/_dashboards/app/management/(.*)"
#           backend {
#             service {

#               name = kubernetes_service.elasticsearch.metadata[0].name
#               port {
#                 number = 80
#               }
#             }
#           }
#         }
#       }
#     }
#     tls {
#       secret_name = "kibana-tls-secret"
#       hosts       = [local.logs_domain]
#     }
#   }
#   depends_on = [kubernetes_namespace.logging]
# }
