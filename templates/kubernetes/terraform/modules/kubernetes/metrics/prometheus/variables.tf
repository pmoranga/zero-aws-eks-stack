variable "project" {
  description = "The name of the project"
}

variable "region" {
  description = "AWS Region"
}

variable "environment" {
  description = "Environment"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
}

variable "prometheus_retention_days" {
  description = "Days of retention for Prometheus stats"
  type        = number
  default     = 90
}

variable "prometheus_storage_capacity" {
  description = "Storage capacity for Prometheus stat data in Gibibytes"
  type        = number
  default     = 50
}

variable "grafana_disable" {
  description = "Disable Grafana, set to true to run prometheus headless"
  default = false
}
variable "grafana_domain" {
  description = "Internal domain in which to create an ingress"
  type        = string
  default     = ""
}

variable "grafana_ingress_annotations" {
  type = map(string)
  default = {}
  description = "Annotations to add to the ingress"
}

variable "elasticsearch_domain" {
  description = "Name of elasticsearch cluster to add as a data source"
  type        = string
  default     = ""
}

variable "elasticsearch_url" {
  description = "Elasticsearch url, to usage with a custom ElasticSearch"
  type = string
  default = ""
}

variable "grafana_plugins" {
  description = "List of plugins to install on grafana"
  type = list(string)
  default = []
}

variable "use_oauth2_proxy" {
  description = "Should we use headers set by oauth2_proxy ?"
  type = bool
  default = false
}

variable "grafana_externally" {
    type = bool
    default = false

}

variable "metrics_collect_labels" {
  description = "Labels to be scrapped by kube-state-metrics to be added to prometheus, key should be resource names in their plural and the list should contain all labels desired for that resource name: example `{\"nodes\":[\"size\",\"node.kubernetes.io/instance-type\"]}`"
  type = map(list(string))
  default = {}
}