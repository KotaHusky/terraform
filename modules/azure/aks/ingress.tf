variable "helm_users_group_id" {
  description = "The group ID for Helm users"
  type        = string
}

resource "azurerm_role_assignment" "helm_users" {
  principal_id         = var.helm_users_group_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  scope                = azurerm_kubernetes_cluster.aks.id
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.6"

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

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = "kota-dog-ingress"
  }
}