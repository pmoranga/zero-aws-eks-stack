variable "region" {
  description = "AWS Region"
}

variable "environment" {
  description = "Environment"
}

variable "elasticsearch_domain" {
  description = "Elasticsearch domain to write logs to"
}

variable "domain_name" {
  description = "the parent domain"
}

variable "elasticsearch_url" {
  description = "Elasticsearch url, to usage with a custom ElasticSearch"
  type = string
  default = ""
}