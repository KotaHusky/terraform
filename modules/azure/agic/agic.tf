variable "application_gateway_id" {}
variable "application_gateway_name" {}
variable "resource_group_name" {}
variable "kubelet_identity" {}
variable "kubelet_client_id" {}
variable "namespace" {
  default = "default"
}

resource "azurerm_role_assignment" "agic_role" {
  scope                = var.application_gateway_id
  role_definition_name = "Contributor"
  principal_id         = var.kubelet_identity
}

resource "helm_release" "agic" {
  name       = "agic"
  repository = "https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/"
  chart      = "ingress-azure"
  namespace  = var.namespace

  set {
    name  = "appgw.resourceGroup"
    value = var.resource_group_name
  }

  set {
    name  = "appgw.name"
    value = var.application_gateway_name
  }

  set {
    name  = "armAuth.type"
    value = "aadPodIdentity"
  }

  set {
    name  = "armAuth.identityResourceID"
    value = var.kubelet_identity
  }

  set {
    name  = "armAuth.identityClientID"
    value = var.kubelet_client_id
  }

  set {
    name  = "kubernetes.watchNamespace"
    value = var.namespace
  }
}

output "helm_release_name" {
  value = helm_release.agic.name
}
