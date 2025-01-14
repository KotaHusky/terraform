variable "name" {}
variable "location" {}
variable "resource_group_name" {}
variable "subnet_id" {}
variable "public_ip_id" {}
variable "tags" { type = map(string) }

resource "azurerm_application_gateway" "app_gateway" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
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
    name               = "httpRule"
    rule_type          = "Basic"
    http_listener_name = "httpListener"
    backend_address_pool_name = "dynamicPool"
    backend_http_settings_name = "httpSetting"
  }

  backend_http_settings {
    name                  = "httpSetting"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  tags = var.tags
}

output "id" {
  value = azurerm_application_gateway.app_gateway.id
}

output "name" {
  value = azurerm_application_gateway.app_gateway.name
}