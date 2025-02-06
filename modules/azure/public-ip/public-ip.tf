variable "name" {}
variable "location" {}
variable "resource_group_name" {}
variable "allocation_method" { default = "Static" }
variable "sku" { default = "Standard" }
variable "tags" { type = map(string) }

resource "azurerm_public_ip" "public_ip" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.allocation_method
  sku                 = var.sku
  tags = var.tags
  lifecycle {
    prevent_destroy = true
  }
}

output "id" {
  value = azurerm_public_ip.public_ip.id
}

output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
}
