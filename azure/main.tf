provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "aks" {
  name     = "aks-shared"
  location = var.location
}

module "aks" {
  source              = "./aks-shared"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  name                = "aks-shared-prod"
}

module "acr" {
  source              = "./acr-shared"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  name                = "kotahuskyacrshared"
  kubelet_identity    = module.aks.kubelet_identity
}