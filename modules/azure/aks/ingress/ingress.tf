variable "helm_users_group_id" {
  description = "The group ID for Helm users"
  type        = string
}

variable "cluster_id" {
  description = "The ID of the AKS cluster"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The location of the resources"
  type        = string
}

module "public_ip" {
  source              = "../../public-ip"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "helm_users" {
  principal_id         = var.helm_users_group_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  scope                = var.cluster_id
}

data "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "nginx_ingress" {
  depends_on = [
    data.kubernetes_namespace.ingress_nginx,
    module.public_ip.public_ip_address
  ]
  name       = "nginx-ingress"
  namespace  = data.kubernetes_namespace.ingress_nginx.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.6"

  set {
    name  = "controller.service.loadBalancerIP"
    value = module.public_ip.public_ip_address
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = var.resource_group_name
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = "kota-dog-ingress"
  }

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set {
    name  = "controller.admissionWebhooks.patch.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }
}