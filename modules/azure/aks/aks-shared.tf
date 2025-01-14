variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name" {
  type = string
}

variable "admin_group_object_id" {
  description = "The object ID of the Azure AD group that will have admin access to the AKS cluster"
  type        = string
}

module "vnet" {
  source              = "../vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  name                = var.name
  address_space       = ["10.0.0.0/16"]
  subnets = [
    {
      name           = "${var.name}-subnet"
      address_prefix = "10.0.1.0/24"
    }
  ]
  tags = {}
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name}-cluster"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.name}-dns"

  default_node_pool {
    name            = "default"
    node_count      = 1
    vm_size         = "Standard_B2s"
    vnet_subnet_id  = module.vnet.subnet_ids["${var.name}-subnet"]
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.0.2.0/24"
    dns_service_ip = "10.0.2.10"
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    admin_group_object_ids  = [var.admin_group_object_id]
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_role_assignment" "aks_subnet" {
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  role_definition_name = "Network Contributor"
  scope                = module.vnet.subnet_ids["${var.name}-subnet"]
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config[0]
}

output "kube_admin_config" {
  value = azurerm_kubernetes_cluster.aks.kube_admin_config[0]
}

output "kubelet_identity" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "kubelet_client_id" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].client_id
}

output "aks_id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "subnet_id" {
  value = module.vnet.subnet_ids["${var.name}-subnet"]
}