variable "region" {
  description = "AWS Region"
}

variable "project" {
  description = "The name of the project"
}

variable "allowed_account_ids" {
  description = "The IDs of AWS accounts for this project, to protect against mistakenly applying to the wrong env"
  type        = list(string)
}

variable "environment" {
  description = "Environment (prod/stage)"
}

variable "random_seed" {
  description = "A randomly generated string to prevent collisions of resource names - should be unique within an AWS account"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
}

variable "external_dns_zones" {
  description = "Domains of R53 zones that external-dns and cert-manager will have access to"
  type        = list(string)
}

variable "external_dns_owner_id" {
  description = "Unique id of the TXT record that external-dns will use to store state (can just be a uuid)"
}

variable "cert_manager_use_production_acme_environment" {
  description = "ACME (LetsEncrypt) Environment - only production creates valid certificates but it has lower rate limits than staging"
  type        = bool
  default     = true
}

variable "cert_manager_acme_registration_email" {
  description = "Email to associate with ACME account when registering with LetsEncrypt"
}

variable "logging_type" {
  description = "Which application logging mechanism to use (cloudwatch, kibana)"
  type        = string
  default     = "cloudwatch"

  validation {
    condition = (
      var.logging_type == "cloudwatch" || var.logging_type == "kibana" || var.logging_type == "none"
    )
    error_message = "Invalid value. Valid values are cloudwatch, kibana, or none."
  }
}

variable "logging_elasticsearch_url" {
  description = "Elasticsearch url, to use with a custom OpenSearch/ElasticSearch already provisioned"
  type        = string
  default     = ""
}

variable "metrics_type" {
  description = "Which application metrics mechanism to use (prometheus, none)"
  type        = string
  default     = "none"

  validation {
    condition = (
      var.metrics_type == "prometheus" || var.metrics_type == "none"
    )
    error_message = "Invalid value. Valid values are none or prometheus."
  }
}

variable "metrics_collect_labels" {
  description = "Labels to be scrapped by kube-state-metrics when using `metrics_type=\"prometheus\"` to be added to prometheus, key should be resource names in their plural and the list should contain all labels desired for that resource name: example `{\"nodes\":[\"size\",\"node.kubernetes.io/instance-type\"]}`"
  type = map(list(string))
  default = {}
}

variable "metrics_open_grafana_externally" {
  description = "When metrics `type` = `prometheus` and `oauth2_proxy_install` enabled, it creates an ingress using `grafana.$${domain_name}` and requiring"
  type        = bool
  default     = false
  # validation {
  #   condition = (
  #     var.metrics_type == "prometheus" && var.oauth2_proxy_install == true
  #   )
  #   error_message = "Required values: `metrics_type` should be `prometheus` and `oauth2_proxy_install` should be `true`"
  # }
}

variable "application_policy_list" {
  description = "Application policies"
  type        = list(any)
  default     = []
}

variable "vpn_server_address" {
  description = "VPN server address"
  type        = string
}

variable "vpn_client_publickeys" {
  type        = list(tuple([string, string, string]))
  description = "VPN List of client name, IP and public key"
}

variable "cf_signing_enabled" {
  type        = bool
  description = "Enable CloudFront signed URLs"
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = ""
}

variable "grafana_domain" {
  description = "Internal domain to create records in"
  type        = string
  default     = ""
}

variable "grafana_ingress_annotations" {
  type        = map(string)
  default     = {}
  description = "Annotations to add to the ingress"
}
variable "notification_service_enabled" {
  description = "If enabled, will install the Zero notification service in the cluster to enable easy implementation of notification via email, sms, push, etc."
  type        = bool
  default     = false
}

variable "notification_service_highly_available" {
  description = "If enabled, will make sure a minimum of 2 pods are running and use a horizontal pod autoscaler to make scale the number of pods based on CPU. Recommended for Production."
  type        = bool
  default     = true
}

variable "notification_service_twilio_phone_number" {
  description = "Twilio Phone Number is the Send from number for your SMS messages for the notification service"
  type        = string
  default     = ""
}

variable "cache_store" {
  description = "Cache store - redis or memcached"
  type        = string
  default     = "none"
}

variable "user_auth" {
  description = "a list of maps configuring oathkeeper instances"
  default     = []

  type = list(object({
    name                        = string
    frontend_service_domain     = string
    backend_service_domain      = string
    auth_namespace              = string
    kratos_secret_name          = string
    jwks_secret_name            = string
    user_auth_mail_from_address = string
    whitelisted_return_urls     = list(string)
    cookie_signing_secret_key   = string
    kratos_values_override      = map(any)
    oathkeeper_values_override  = map(any)
  }))
}

variable "user_auth_dev_env_enabled" {
  description = "When enabled will provision Kratos and Oathkeeper Rules for dev environment"
  type        = bool
  default     = false
}

variable "dev_user_auth_frontend_domain" {
  description = "Frontend domain used for local development with dev env"
  type        = string
  default     = "127.0.0.1:3000"
}

variable "nginx_ingress_replicas" {
  description = "The number of ingress controller pods to run in the cluster. Production environments should not have less than 2"
  type        = number
  default     = 2
}

variable "enable_node_termination_handler" {
  description = "The Node Termination Handler should be enabled when using spot instances in your cluster, as it is responsible for gracefully draining a node that is due to be terminated. It can also be used to cleanly handle scheduled maintenance events on On-Demand instances, though it runs as a daemonset, so will run 1 pod on each node in your cluster"
  type        = bool
  default     = false
}

variable "create_database_service" {
  description = "For ease of use, create an 'ExternalName' type service called 'database' in the application's namespace that points at the app db. The db will be auto-discovered based on its name"
  type        = bool
  default     = true
}

variable "k8s_role_mapping" {
  type = list(object({
    name     = string
    policies = list(map(list(string)))
    groups   = list(string)
  }))
  description = "List of Kubernetes Policies and Groups to create and map to IAM roles"
}

variable "assumerole_account_ids" {
  description = "AWS account IDs that will be allowed to assume the roles we are creating. If left blank, the 'allowed_account_ids' will be used"
  type        = list(string)
  default     = []
}

variable "oauth2_proxy_install" {
  description = "Install OAuth Proxy limiting to authenticate any domain ?"
  type        = bool
  default     = false
}

variable "oauth2_external_secret_name" {
  description = "The External secret with 3 keys as defined here https://github.com/oauth2-proxy/manifests/blob/main/helm/oauth2-proxy/templates/secret.yaml"
  type        = string
  default     = "<% .Name %>/application/stage/oauth2proxy"
}

variable "oauth2_keycloak_oidc_issuer_url" {
  description = "The URL for the KeyCloak Issuer"
  default = "" 
  type = string 
}

variable "oauth2_keycloak_enabled" {
  description = "Should we use a keycloak backend for authentication (otherwise it will use google)"
  default = false
  type = bool 
}


variable "echoheader_enabled" {
  description = "Enable echo-header helm deployment"
  type        = bool
  default     = false
}

variable "enable_keycloak" {
  description = "Enable [keycloak]() service ?"
  type        = bool
  default     = false
}

variable "keycloak_external_secret_name" {
  description = "The External secret for KeyCloak"
  type        = string
  default     = "<% .Name %>/application/ops/keycloak"
}

variable "grafana_plugins" {
  description = "List of plugins to install on grafana"
  type        = list(string)
  default     = []
}

variable "ingress_nginx_internal_enabled" {
  description = "Enable second Internal Ingress NGINX controller for internal ALB"
  type        = bool
  default     = false
}

variable "keda_enabled" {
  description = "Enable Keda Auto - Scaler"
  type        = bool
  default     = false
}

variable "autoscaler_expander_priorities" {
  description = <<EOF
When defined it will enable the Expander Expander and provide the configuration passed here as the expander priorities. 
For more details check https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/expander/priority/readme.md"

Example:
```
  autoscaler_expander_priorities = {
        "10": ".*"
        "90": [
          ".*t3\\.*",
          ".*t3a\\.*",
          ]
      }
```
This example will always prefer to allocate instances `t3a?`, over the rest (`.*` default fallback)
EOF
  type = map(list(string))
  default = {}
}