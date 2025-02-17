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

variable "subnet_id" {
  description = "The ID of the subnet for the AKS cluster"
  type        = string
}

variable "service_cidr" {
  description = "The CIDR block for the Kubernetes service network"
  type        = string
}

variable "pod_cidr" {
  description = "The CIDR block for the Kubernetes pod network"
  type        = string
}

variable "dns_service_ip" {
  description = "The IP address within the service CIDR to use for DNS"
  type        = string
}

variable "resource_group_id" {
  description = "The ID of the resource group"
  type        = string
}
variable "outbound_ip_address_ids" {
  description = "The IDs of the outbound IP addresses"
  type        = list(string)
}

resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "${var.name}-aks-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name}-cluster"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.name}-dns"

  default_node_pool {
    name            = "default"
    node_count      = 2
    vm_size         = "Standard_B2s"
    vnet_subnet_id  = var.subnet_id
  }

  network_profile {
    network_plugin = "kubenet"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
    pod_cidr       = var.pod_cidr
    load_balancer_sku = "standard"

    load_balancer_profile {
      outbound_ip_address_ids = var.outbound_ip_address_ids
    }

    outbound_type = "loadBalancer"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aks_identity.id
    ]
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    admin_group_object_ids  = [var.admin_group_object_id]
  }

  tags = {
    environment = "production"
  }
}

# Role Assignments for AKS Subnet
resource "azurerm_role_assignment" "aks_subnet" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  role_definition_name = "Network Contributor"
  scope                = var.subnet_id
}

# Role Assignments for AKS Cluster
resource "azurerm_role_assignment" "aks_cluster_user_role" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.admin_group_object_id
}

resource "azurerm_role_assignment" "aks_cluster_admin_role" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.admin_group_object_id
}

# Role Assignment for Ingress Controller
resource "azurerm_role_assignment" "ingress_controller_role" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  role_definition_name = "Contributor"
  scope                = var.resource_group_id # Assign scope to the resource group
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

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "identity_client_id" {
  value = azurerm_user_assigned_identity.aks_identity.client_id
}

output "identity_resource_id" {
  value = azurerm_user_assigned_identity.aks_identity.id
}
