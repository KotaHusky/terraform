variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "kubelet_identity" {
  type = string
}

resource "azurerm_container_registry" "acr" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = var.kubelet_identity
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}