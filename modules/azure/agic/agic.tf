terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

variable "application_gateway_id" {}
variable "application_gateway_name" {}
variable "resource_group_name" {}
variable "kubelet_identity" {}
variable "kubelet_client_id" {}
variable "namespace" {
  default = "agic"
}
variable "aks_cluster_name" {}

# Deploy the Azure AD Pod Identity CRDs
resource "kubectl_manifest" "aadpodidentity_crds" {
  provider = kubectl
  yaml_body = file("${path.module}/manifests/aadpodidentity-crds.yaml")
}

# Deploy the AzureIngressProhibitedTarget CRD
resource "kubectl_manifest" "azure_ingress_prohibited_target_crd" {
  provider = kubectl
  depends_on = [kubectl_manifest.aadpodidentity_crds]
  yaml_body  = file("${path.module}/manifests/prohibited-target-crd.yaml")
}

# Deploy the AzureIngressProhibitedTarget resource
resource "kubectl_manifest" "prohibit_all_except_webapp" {
  provider = kubectl
  depends_on = [kubectl_manifest.azure_ingress_prohibited_target_crd]
  yaml_body  = file("${path.module}/manifests/prohibit-all-except-webapp.yaml")
}

# Deploy AGIC and Pod Identity Helm Charts
resource "azurerm_role_assignment" "agic_role" {
  scope                = var.application_gateway_id
  role_definition_name = "Contributor"
  principal_id         = var.kubelet_identity
}

resource "helm_release" "agic" {
  depends_on = [
    kubectl_manifest.prohibit_all_except_webapp,
    kubectl_manifest.aadpodidentity_crds
  ]

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
