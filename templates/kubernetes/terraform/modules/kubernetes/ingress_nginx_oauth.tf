# This enables OAuth2-Proxy for all the domains unless specified annotation to bypass it.
# please check https://github.com/oauth2-proxy/oauth2-proxy


locals {
  # oauth2_provider = "github"
  oauth2_provider          = var.oauth2_keycloak_enabled ? "keycloak-oidc" : "google"
  oauth2_root_domain       = ".${var.domain_name}"
  oauth2_auth_domain       = "auth${local.oauth2_root_domain}"
  oauth2_namespace         = "oauth2-proxy"
  oauth2_secretname        = "${local.oauth2_namespace}-secret"
  oauth2_whitelist_domains = ["wearemove.io"]

  oauth2_nginx_ingress_options = var.oauth2_proxy_install ? {
    "global-auth-signin" = "https://${local.oauth2_auth_domain}/oauth2/start?rd=https%3A%2F%2F$host$request_uri"
    "global-auth-url"    = "https://${local.oauth2_auth_domain}/oauth2/auth"
    "global-auth-response-headers" : "X-Auth-Request-User, X-Auth-Request-Email, X-Auth-Request-Access-Token, X-Auth-Request-Groups, X-Auth-Request-Preferred-Username"
  } : {}


  oauth2_external_secret_definition = {
    apiVersion : "kubernetes-client.io/v1"
    kind : "ExternalSecret"

    metadata : {
      name : local.oauth2_secretname
      namespace : local.oauth2_namespace
    }
    spec : {
      backendType : "secretsManager"
      dataFrom : [var.oauth2_external_secret_name]
    }
  }
}


resource "kubernetes_namespace" "oauth2_proxy" {
  count = var.oauth2_proxy_install ? 1 : 0

  metadata {
    annotations = {
      name = local.oauth2_namespace
    }

    labels = {
      mylabel = local.oauth2_namespace
    }

    name = local.oauth2_namespace
  }
}

resource "helm_release" "oauth2_proxy" {
  count = var.oauth2_proxy_install ? 1 : 0

  name       = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "6.24.1"
  namespace  = kubernetes_namespace.oauth2_proxy[0].metadata[0].name
  depends_on = [
    kubernetes_namespace.oauth2_proxy,
    kubectl_manifest.oauth2_external_secret_custom_resource,
    helm_release.external_secrets,
  ]

  values = [yamlencode({
    "config" : {
      "existingSecret" : local.oauth2_secretname,
      "cookieName" : "CookieAuth"
      # "configFile" : "upstreams = [ \"file:///dev/null\" ]\nemail_domains = [] # Fix for email whitelist - https://github.com/oauth2-proxy/oauth2-proxy/issues/73#issuecomment-479887956"

      configFile : <<EOF
    email_domains = [ "*" ]
    cookie_secure = "false"
    provider = "google"
    EOF
    },
    "proxyVarsAsSecrets" : true,
    "extraArgs" : merge({
      "whitelist-domain" : local.oauth2_root_domain,
      "cookie-domain" : local.oauth2_root_domain,
      "set-xauthrequest" : "true",
      "pass-authorization-header" : "true",
      "provider" : local.oauth2_provider,
      "pass-access-token" : true,
      "pass-user-headers" : true,
      "skip-auth-route" : "GET=/favicon.*",
      "cookie-samesite" : "none", # To allow to receive the cookies on the iframe.
      "cookie-secure" : true,     # To allow to receive the cookies on the iframe.

      },
      var.oauth2_keycloak_enabled == false ? {} : {
        provider : "keycloak-oidc"
        redirect-url : "https://${local.oauth2_auth_domain}/oauth2/callback"
        oidc-issuer-url : var.oauth2_keycloak_oidc_issuer_url             # For Keycloak versions <17: --oidc-issuer-url: "https://<keycloak host>/auth/realms/<your realm>
        code-challenge-method : "S256"                                    # PKCE
        insecure-oidc-allow-unverified-email: true
        # email-domain : "<yourcompany.com>"                              # Validate email domain for users, see option documentation
        # allowed-role : "<realm role name>"                              # Optional, required realm role
        # allowed-role : "<client id>:<client role name>"                 # Optional, required client role
        # allowed-group : "</group name>"                                 # Optional, requires group client scope
      }
    ),
    "ingress" : {
      "enabled" : true,
      "path" : "/",
      "hosts" : [
        local.oauth2_auth_domain
      ],
      "annotations" : {
        "kubernetes.io/ingress.class" : "nginx",
        "cert-manager.io/cluster-issuer" : "letsencrypt-prod",
        "cert-manager.io/cluster-issuer" : "clusterissuer-letsencrypt-production",
        "nginx.ingress.kubernetes.io/enable-global-auth" : "false"
      },
      "tls" : [
        {
          "secretName" : "oauth2-proxy-https-cert",
          "hosts" : [
            local.oauth2_auth_domain
          ]
        }
      ]
    },
    "podDisruptionBudget" : {
      "enabled" : false
    }
  })]
}

resource "kubectl_manifest" "oauth2_external_secret_custom_resource" {
  count = var.oauth2_proxy_install ? 1 : 0

  yaml_body  = yamlencode(local.oauth2_external_secret_definition)
  depends_on = [kubernetes_namespace.oauth2_proxy]
}

# resource "null_resource" "oauth2_external_secret_custom_resource" {

#   triggers = {
#     manifest_sha1 = sha1(jsonencode(local.oauth2_external_secret_definition))
#   }

#   provisioner "local-exec" {
#     command = "kubectl apply ${local.k8s_exec_context} -n ${kubernetes_namespace.oauth2_proxy[0].metadata[0].name} -f - <<EOF\n${jsonencode(local.oauth2_external_secret_definition)}\nEOF"
#   }

#   depends_on = [kubernetes_namespace.oauth2_proxy]
# }







