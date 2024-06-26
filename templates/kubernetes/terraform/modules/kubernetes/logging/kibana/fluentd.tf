locals {
  fluentd_image = "fluent/fluentd-kubernetes-daemonset:v1.16-debian-opensearch-2"
}

# Look up the elasticsearch cluster
data "aws_elasticsearch_domain" "logging_cluster" {
  count = var.elasticsearch_url == "" ? 1 : 0

  domain_name = var.elasticsearch_domain
}

resource "kubernetes_service_account" "fluentd" {
  metadata {
    name      = "fluentd"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "fluentd_role" {
  metadata {
    name = "fluentd-role"
  }
  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["namespaces", "pods", "pods/logs"]
  }
}

resource "kubernetes_cluster_role_binding" "fluentd_role_binding" {
  metadata {
    name = "fluentd-role-binding"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluentd.metadata[0].name
    namespace = kubernetes_namespace.logging.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "fluentd-role"
  }
}

# The config file for fluentd
data "local_file" "application" {
  filename = "${path.module}/files/fluentd-application.conf"
}

data "local_file" "fluent_conf" {
  filename = "${path.module}/files/fluent.conf"
}

# Store the config file into a configmap
resource "kubernetes_config_map" "fluentd_configd" {
  metadata {
    name      = "fluentd-es-config"
    namespace = kubernetes_namespace.logging.metadata[0].name
    labels    = { k8s-app = "fluentd" }
  }
  data = {
    "application.conf" = data.local_file.application.content
  }
}

resource "kubernetes_config_map" "fluentd_config" {
  metadata {
    name      = "fluentd-es-configd"
    namespace = kubernetes_namespace.logging.metadata[0].name
    labels    = { k8s-app = "fluentd" }
  }
  data = {
    "fluent.conf" = data.local_file.fluent_conf.content
  }
}

# Create the daemonset. This will start fluentd pods on each node to capture logs and send to Elasticsearch
resource "kubernetes_daemonset" "fluentd" {
  metadata {
    name      = "fluentd"
    namespace = kubernetes_namespace.logging.metadata[0].name
    labels = {
      k8s-app = "fluentd"
    }
  }
  spec {
    selector {
      match_labels = {
        k8s-app = "fluentd"
      }
    }
    template {
      metadata {
        labels = {
          k8s-app = "fluentd"
          assets-hash = sha1(format("%s\n%s",
            data.local_file.fluent_conf.content,
            data.local_file.application.content))
        }
      }
      spec {
        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.fluentd_config.metadata[0].name
          }
        }

        volume {
          name = "config-volumed"
          config_map {
            name = kubernetes_config_map.fluentd_configd.metadata[0].name
          }
        }
        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }
        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }
        volume {
          name = "dmesg"
          host_path {
            path = "/var/log/dmesg"
          }
        }

        container {
          name  = "fluentd"
          image = local.fluentd_image

          env {
            name  = "FLUENT_OPENSEARCH_HOST"
            value = var.elasticsearch_url == "" ? data.aws_elasticsearch_domain.logging_cluster[0].endpoint : var.elasticsearch_url
          }
          env {
            name  = "FLUENT_OPENSEARCH_PORT"
            value = "443"
          }
          env {
            name  = "FLUENT_OPENSEARCH_SCHEME"
            value = "https"
          }
          env {
            name  = "FLUENT_OPENSEARCH_PATH"
            value = "/"
          }
          env {
            name  = "FLUENT_UID"
            value = "0"
          }
          env {
            name  = "FLUENT_OPENSEARCH_INDEX_NAME"
            value = "fluentd-${var.environment}"
          }
          env {
            name  = "FLUENT_OPENSEARCH_LOGSTASH_PREFIX"
            value = "fluentd-${var.environment}"
          }

          env {
            name  = "FLUENT_OPENSEARCH_BUFFER_CHUNK_LIMIT_SIZE"
            value = "1M"
          }

          env {
            name  = "FLUENT_OPENSEARCH_LOGSTASH_FORMAT"
            value = "true"
          }
          # env {
          #   name = "FLUENT_CONTAINER_TAIL_PARSER_TIME_FORMAT"
          #   value = "%Y-%m-%dT%H:%M:%S.%N%:z"
          # }
          env {
            name  = "FLUENT_CONTAINER_TAIL_EXCLUDE_PATH"
            value = "/var/log/containers/fluent*"
          }
          env {
            name  = "FLUENT_CONTAINER_TAIL_PARSER_TYPE"
            value = "cri"
          }
          env {
            name  = "FLUENTD_SYSTEMD_CONF"
            value = "disable"
          }
          env {
            name = "FLUENT_ENVIRONMENT_NAME"
            value = var.environment
          }

          # env {
          #   name  = "FLUENT_CONTAINER_TAIL_TAG"
          #   value = "kubernetes"
          # }

          env {
            name = "K8S_NODE_NAME"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "spec.nodeName"
              }
            }
          }
          # env {
          #   name  = "FLUENT_ELASTICSEARCH_LOG_ES_400_REASON"
          #   value = "true"
          # }
          # Uncomment the following for verbose logging if testing config changes
          # env {
          #   name  = "FLUENTD_OPT"
          #   value = "-v"
          # }

          resources {
            limits = {
              cpu    = "900m"
              memory = "500Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/fluentd/etc/fluent.conf"
            #subPath: move-custom.ini
            sub_path = "fluent.conf"
          }
          volume_mount {
            name       = "config-volumed"
            mount_path = "/fluentd/etc/conf.d/"
          }
          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
          }
          volume_mount {
            name       = "varlibdockercontainers"
            read_only  = true
            mount_path = "/var/lib/docker/containers"
          }
          volume_mount {
            name       = "dmesg"
            read_only  = true
            mount_path = "/var/log/dmesg"
          }
        }

        termination_grace_period_seconds = 30
        service_account_name             = kubernetes_service_account.fluentd.metadata[0].name
        automount_service_account_token  = true
      }
    }
  }
}
