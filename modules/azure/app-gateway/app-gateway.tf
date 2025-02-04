variable "name" {
  description = "The name of the Application Gateway"
  type        = string
}

variable "location" {
  description = "The location of the Application Gateway"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "public_ip_id" {
  description = "The ID of the public IP address"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
}

resource "azurerm_user_assigned_identity" "app_gateway_identity" {
  name                = "${var.name}-appgateway-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_application_gateway" "app_gateway" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = "Basic"
    tier     = "Basic"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "myIPConfig"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "httpPort"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontendConfig"
    public_ip_address_id = var.public_ip_id
  }

  backend_address_pool {
    name = "dynamicPool"
  }

  http_listener {
    name                           = "httpListener"
    frontend_ip_configuration_name = "frontendConfig"
    frontend_port_name             = "httpPort"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "httpRule"
    rule_type                  = "Basic"
    http_listener_name         = "httpListener"
    backend_address_pool_name  = "dynamicPool"
    backend_http_settings_name = "httpSettings"
    priority                   = 100
  }

  backend_http_settings {
    name                  = "httpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.app_gateway_identity.id
    ]
  }

  tags = var.tags
}

output "application_gateway_id" {
  value = azurerm_application_gateway.app_gateway.id
}

output "application_gateway_name" {
  value = azurerm_application_gateway.app_gateway.name
}

output "identity_client_id" {
  value = azurerm_user_assigned_identity.app_gateway_identity.client_id
}

output "identity_resource_id" {
  value = azurerm_user_assigned_identity.app_gateway_identity.id
}

output "app_gateway_identity_principal_id" {
  value = azurerm_user_assigned_identity.app_gateway_identity.principal_id
}
