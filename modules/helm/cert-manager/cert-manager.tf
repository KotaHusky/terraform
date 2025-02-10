terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.18.0"
    }
  }
}

variable "namespace" {
  type    = string
  default = "cert-manager"
}

variable "chart_version" {
  type    = string
  default = "v1.17.0"
}

variable "install_crds" {
  type    = bool
  default = true
}

# Install the cert-manager Helm chart from Jetstack
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = var.namespace
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_version
  create_namespace = true

  set {
    name  = "installCRDs"
    value = var.install_crds
  }
}