variable "name" {}
variable "location" {}
variable "resource_group_name" {}
variable "public_ip_id" {}
variable "subnet_id" {}
variable "tags" { type = map(string) }

resource "azurerm_lb" "load_balancer" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = var.public_ip_id
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name                = "${var.name}-backend-pool"
  loadbalancer_id     = azurerm_lb.load_balancer.id
}

resource "azurerm_lb_probe" "http_probe" {
  name                = "${var.name}-http-probe"
  loadbalancer_id     = azurerm_lb.load_balancer.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http_rule" {
  name                           = "${var.name}-http-rule"
  loadbalancer_id                = azurerm_lb.load_balancer.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  probe_id                       = azurerm_lb_probe.http_probe.id
}

output "load_balancer_id" {
  value = azurerm_lb.load_balancer.id
}

output "backend_pool_id" {
  value = azurerm_lb_backend_address_pool.backend_pool.id
}