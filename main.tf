terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

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
    host                   = module.aks.kube_admin_config.host
    client_certificate     = base64decode(module.aks.kube_admin_config.client_certificate)
    client_key             = base64decode(module.aks.kube_admin_config.client_key)
    cluster_ca_certificate = base64decode(module.aks.kube_admin_config.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = module.aks.kube_admin_config.host
  client_certificate     = base64decode(module.aks.kube_admin_config.client_certificate)
  client_key             = base64decode(module.aks.kube_admin_config.client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_admin_config.cluster_ca_certificate)
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

variable "resource_name_prefix" {
  description = "The prefix for resource names"
  type        = string
  default     = "aks-shared"
}

variable "acr_name" {
  description = "The name of the Azure Container Registry. Must be globally unique."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the resources"
  type        = map(string)
  default     = {
    Environment = "Production"
  }
}

variable "vnet_cidr" {
  description = "The CIDR block for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "The CIDR block for the AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "appgw_subnet_cidr" {
  description = "The CIDR block for the Application Gateway subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "service_cidr" {
  description = "The CIDR block for the Kubernetes service network"
  type        = string
  default     = "10.0.3.0/24"
}

variable "dns_service_ip" {
  description = "The IP address within the service CIDR to use for DNS"
  type        = string
  default     = "10.0.3.10"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_name_prefix
  location = var.location
}

# Namespaces
resource "kubernetes_namespace" "webapps" {
  metadata {
    name = "webapps"
  }
}

resource "kubernetes_namespace" "agic" {
  metadata {
    name = "agic"
  }
}

# Modules
## Virtual Network Module
module "vnet" {
  source              = "./modules/azure/vnet"
  name                = "${var.resource_name_prefix}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

## Subnet Module
module "subnet" {
  source              = "./modules/azure/subnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = module.vnet.name
  name                = "${var.resource_name_prefix}-subnets"
  subnets = [
    {
      name           = "${var.resource_name_prefix}-aks-subnet"
      address_prefix = var.aks_subnet_cidr
    },
    {
      name           = "${var.resource_name_prefix}-appgw-subnet"
      address_prefix = var.appgw_subnet_cidr
    }
  ]
}

## AKS Admins Module
module "aks_admins" {
  source                = "./modules/azure/entra-id"
  admin_user_object_id  = var.admin_user_object_id
}

## AKS Cluster Module
module "aks" {
  source                = "./modules/azure/aks"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  name                  = "${var.resource_name_prefix}-prod"
  admin_group_object_id = module.aks_admins.aks_admins_group_id
  subnet_id             = module.subnet.subnet_ids["${var.resource_name_prefix}-aks-subnet"]
  service_cidr          = var.service_cidr
  dns_service_ip        = var.dns_service_ip
}

## Azure Container Registry (ACR) Module
module "acr" {
  source              = "./modules/azure/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  name                = "${var.acr_name}"
  kubelet_identity    = module.aks.kubelet_identity
}

## Azure Application Gateway Module
module "app_gateway" {
  source              = "./modules/azure/app-gateway"
  name                = "${var.resource_name_prefix}-app-gateway"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = module.subnet.subnet_ids["${var.resource_name_prefix}-appgw-subnet"]
  public_ip_id        = module.public_ip.id
  tags                = var.tags
}

## Public IP Module
module "public_ip" {
  source              = "./modules/azure/public-ip"
  name                = "${var.resource_name_prefix}-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

## AGIC Module
module "agic" {
  source                  = "./modules/azure/agic"
  application_gateway_id  = module.app_gateway.application_gateway_id
  application_gateway_name = module.app_gateway.application_gateway_name
  resource_group_name     = azurerm_resource_group.rg.name
  kubelet_identity        = module.aks.kubelet_identity
  kubelet_client_id       = module.aks.kubelet_client_id
  namespace               = "agic"
  aks_cluster_name        = module.aks.aks_cluster_name
  providers = {
    kubectl = kubectl
  }

  depends_on = [module.aks]
}