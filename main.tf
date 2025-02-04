terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
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
  lifecycle {
    prevent_destroy = true
  }
}

# Namespaces
resource "kubernetes_namespace" "webapps" {
  metadata {
    name = "webapps"
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
  resource_group_id     = azurerm_resource_group.rg.id
  load_balancer_id      = module.load_balancer.load_balancer_id
}

## Azure Container Registry (ACR) Module
module "acr" {
  source              = "./modules/azure/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  name                = "${var.acr_name}"
  kubelet_identity    = module.aks.kubelet_identity
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

## Load Balancer Module
module "load_balancer" {
  source              = "./modules/azure/load-balancer"
  name                = "${var.resource_name_prefix}-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  public_ip_id        = module.public_ip.id
  subnet_id           = module.subnet.subnet_ids["${var.resource_name_prefix}-aks-subnet"]
  tags                = var.tags
}

## Random ID for Unique Helm Release Name
resource "random_id" "nginx_ingress" {
  keepers = {
    namespace = "kube-system"
  }
  byte_length = 4
}

## NGINX Ingress Module
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-${random_id.nginx_ingress.hex}"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.6"

  set {
    name  = "controller.replicaCount"
    value = 2
  }

  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set {
    name  = "defaultBackend.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.admissionWebhooks.patch.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = module.public_ip.public_ip_address
  }
}

output "nginx_ingress_status" {
  value = helm_release.nginx_ingress.status
}
