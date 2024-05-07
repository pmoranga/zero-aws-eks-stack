## This install a second Ingress Controller for Internal using NLB. 

# to use it, just use the following annotation to a Ingress
##      nginx-internal


locals {
  ingress_nginx_internal_values = {
    defaultBackend : {
      enabled : false
    }
    controller : {
      ingressClass : "nginx-internal"
      ingressClassByName : "true",

      ingressClassResource : {
        name : "nginx-internal"
        enabled : "true"
        default : "false"
        controllerValue : "k8s.io/ingress-nginx-internal"
      },
      config: {
        allow-snippet-annotations: "true"
      },
      service : {
        # Disable the external LB
        annotations:  {
            "service.beta.kubernetes.io/aws-load-balancer-internal" : "true"
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" : "tcp"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" : "true"
            "service.beta.kubernetes.io/aws-load-balancer-type" : "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags": "Name=k8s-${var.environment}-internal,Project=k8s-${var.environment},Environment=${var.environment}" # #Does not update - needs to do manually## needs re-create LB
          }
        external : {
          enabled : "false"
        }
        # Enable the internal LB. The annotations are important here, without
        # these you will get a "classic" loadbalancer
        # internal : {
        #   enabled : "true"
        #   annotations : {
        #     "service.beta.kubernetes.io/aws-load-balancer-internal" : "true"
        #     "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" : "tcp"
        #     "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" : "true"
        #     "service.beta.kubernetes.io/aws-load-balancer-type" : "nlb"
        #   }
        # }
      }
      metrics : {
        serviceMonitor : {
          enabled : true
        }
      }
    }
  }

  ingress_internal_cm_options = { "use-gzip": "true" }
  ingress_nginx_internal_namespace = "ingress-nginx-internal"
}

resource "kubernetes_namespace" "ingress_nginx_internal" {
  count = var.ingress_nginx_internal_enabled ? 1 : 0

  metadata {
    annotations = {
      name = local.ingress_nginx_internal_namespace
    }

    labels = {
      mylabel = local.ingress_nginx_internal_namespace
    }

    name = local.ingress_nginx_internal_namespace
  }
}

resource "helm_release" "internal_ingress_nginx" {
  count = var.ingress_nginx_internal_enabled ? 1 : 0

  name       = "nginx-internal"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.10.0"
  namespace  = kubernetes_namespace.ingress_nginx_internal[0].metadata[0].name
  depends_on = [
    kubernetes_namespace.ingress_nginx_internal,
  ]
  values = [yamlencode(local.ingress_nginx_internal_values)]
}
