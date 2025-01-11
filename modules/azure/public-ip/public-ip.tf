variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The location of the resources"
  type        = string
}

resource "azurerm_public_ip" "aks_ingress" {
  name                = "aks-ingress-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    environment = "production"
  }
  lifecycle {
    prevent_destroy = true
    create_before_destroy = true
  }
}

output "public_ip_address" {
  value = azurerm_public_ip.aks_ingress.ip_address
}