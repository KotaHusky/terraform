# Providers Configuration
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

provider "kubernetes" {
  host                   = module.aks.kube_admin_config.host
  client_certificate     = base64decode(module.aks.kube_admin_config.client_certificate)
  client_key             = base64decode(module.aks.kube_admin_config.client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_admin_config.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kube_config.host
    client_certificate     = base64decode(module.aks.kube_config.client_certificate)
    client_key             = base64decode(module.aks.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.aks.kube_config.cluster_ca_certificate)
  }
}

# Variables
variable "subscription_id" {
  description = "The subscription ID for Azure"
  type        = string
}

variable "tenant_id" {
  description = "The tenant ID for Azure AD"
  type        = string
}

variable "location" {
  description = "The location of the resources"
  type        = string
  default     = "East US"
}

variable "admin_user_object_id" {
  description = "The object ID of the Azure AD user that will be added to the admin group"
  type        = string
}

# Resource Group
resource "azurerm_resource_group" "aks" {
  name     = "aks-shared"
  location = var.location
}

# Modules
## AKS Admins Module
module "aks_admins" {
  source                = "./modules/azure/entra-id"
  admin_user_object_id  = var.admin_user_object_id
}

## AKS Cluster Module
module "aks" {
  source              = "./modules/azure/aks"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  name                = "aks-shared-prod"
  admin_group_object_id = module.aks_admins.aks_admins_group_id
}

## Azure Container Registry (ACR) Module
module "acr" {
  source              = "./modules/azure/acr"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  name                = "kotahuskyacrshared"
  kubelet_identity    = module.aks.kubelet_identity
}
