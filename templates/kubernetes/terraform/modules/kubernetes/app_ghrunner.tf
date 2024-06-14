locals {
  ghrunner_arc_systems = "gharc-systems"
  ghrunner_arc_runner_prefix = "gharc-runners"
}


resource "helm_release" "gharc-systems" {
  count = var.ghrunner_enabled ? 1 : 0

  name       = "gharc-systems"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts/"
  chart      = "gha-runner-scale-set-controller"

  namespace  = local.ghrunner_arc_systems

  create_namespace = true

}

resource "kubernetes_namespace" "gharc-systems" {
  count = var.ghrunner_enabled ? length(var.ghaction_orgs) : 0

  metadata {
    name = local.ghrunner_arc_systems
  }
}

resource "kubernetes_namespace" "runner-scale-set" {
  count = var.ghrunner_enabled ? length(var.ghaction_orgs) : 0

  metadata {
    name = "${local.ghrunner_arc_runner_prefix}${count.index+1}"
  }
}

resource "helm_release" "runner-scale-set" {
  count = var.ghrunner_enabled ? length(var.ghaction_orgs) : 0

  name       = "runner-scale-set${count.index+1}"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts/"
  chart      = "gha-runner-scale-set"
  version    = "0.8.2"

  namespace  = "${local.ghrunner_arc_runner_prefix}${count.index+1}"

  create_namespace = true

  values = [yamlencode({
    "githubConfigUrl": "https://github.com/${var.ghaction_orgs[count.index]}"
    "githubConfigSecret": "gh-action-secret"
    "runnerScaleSetName": "moverunner"
    "maxRunners": 6
    "minRunners": 1
    "containerMode": { "type": "dind" }
    "template": {
      "spec": {
        "containers": [ 
          {
          "name": "runner",
          "image": var.ghaction_runner_image,
          "imagePullPolicy": "Always",
          "command": ["/home/runner/run.sh"]
          }
        ]
      }
    }
  })]
  depends_on = [  
    kubectl_manifest.gh-action-secret,
    kubernetes_namespace.gharc-systems,
    helm_release.gharc-systems
   ]
}

resource "kubectl_manifest" "gh-action-secret" {
  count = var.ghrunner_enabled ? length(var.ghaction_orgs) : 0

  yaml_body  = yamlencode({
    apiVersion : "kubernetes-client.io/v1"
    kind : "ExternalSecret"

    metadata : {
      name : "gh-action-secret"
      namespace  = "${local.ghrunner_arc_runner_prefix}${count.index+1}"
    }
    spec : {
      backendType : "secretsManager"
      data : [{
        "key": var.ghaction_aws_secret_name
        "name": "github_token"
        "property": "${lower(var.ghaction_orgs[count.index])}.github_token"
      }]
    }
  })
  depends_on = [kubernetes_namespace.runner-scale-set]
}

variable "ghrunner_enabled" {
  description = "Enable the GH Runner"
  default     = false
  type        = bool
}

variable "ghaction_orgs" {
  description = "A list of the Orgs to create assign the runners"
  type = list(string)
  default = []
}

variable "ghaction_runner_image" {
  description = "The image to use for the runners"
  type = string
  default = "ghcr.io/actions/actions-runner:latest"
}

variable "ghaction_aws_secret_name" {
  description = "The key on AWS Secret Manager where the GH Token is, it should be inside the following key there: `ORGNAME.github_token`, where ORGNAME should be in lowercase "
  default = "<% .Name %>/application/stage/ghrunner-token"
}