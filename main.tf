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
  description = "The CIDR block for the virtual network. Should encompass the AKS subnet."
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "The CIDR block for the AKS subnet Should be a subset of the vnet_cidr."
  type        = string
  default     = "10.0.1.0/24"
}

variable "service_cidr" {
  description = "The CIDR block for the Kubernetes service network. Should not overlap with vnet_cidr."
  type        = string
  default     = "10.1.0.0/24"
}

variable "dns_service_ip" {
  description = "The IP address within the service CIDR to use for DNS. Should be within service_cidr."
  type        = string
  default     = "10.1.0.10"
}

variable "pod_cidr" {
  description = "The CIDR block for the Kubernetes pod network. Should not overlap with vnet_cidr."
  type        = string
  default     = "10.2.0.0/16"
}

variable "email" {
  description = "The email address for Let's Encrypt registration"
  type        = string
}

variable "domain" {
  description = "The domain name for the certificate"
  type        = string
}

variable "cloudflare_api_token" {
  description = "The Cloudflare API token for DNS validation"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare zone ID for the domain"
  type        = string
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

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

## ======================================================================
# Modules
## ======================================================================

# Virtual Network Module
module "vnet" {
  source              = "./modules/azure/vnet"
  name                = "${var.resource_name_prefix}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# Subnet Module
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

# AKS Admins Module
module "aks_admins" {
  source                = "./modules/azure/entra-id"
  admin_user_object_id  = var.admin_user_object_id
}

# AKS Cluster Module
module "aks" {
  source                = "./modules/azure/aks"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  name                  = var.resource_name_prefix
  admin_group_object_id = module.aks_admins.aks_admins_group_id
  subnet_id             = module.subnet.subnet_ids["${var.resource_name_prefix}-aks-subnet"]
  service_cidr          = var.service_cidr
  pod_cidr              = var.pod_cidr
  dns_service_ip        = var.dns_service_ip
  resource_group_id     = azurerm_resource_group.rg.id
  outbound_ip_address_ids = [module.public_ip.id]
}

# Azure Container Registry (ACR) Module
module "acr" {
  source              = "./modules/azure/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  name                = "${var.acr_name}"
  kubelet_identity    = module.aks.kubelet_identity
}

# Public IP Module
module "public_ip" {
  source              = "./modules/azure/public-ip"
  name                = "${var.resource_name_prefix}-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Random ID for Unique Helm Release Name
resource "random_id" "nginx_ingress" {
  keepers = {
    namespace = "ingress-nginx"
  }
  byte_length = 4
}

# Helm Release for NGINX Ingress Controller
module "nginx_ingress_controller" {
  name                = "nginx-ingress-${random_id.nginx_ingress.hex}"
  source              = "./modules/helm/nginx-ingress-controller"
  namespace           = "ingress-nginx"
  replica_count       = 2
  load_balancer_ip    = module.public_ip.public_ip_address
  resource_group_name = azurerm_resource_group.rg.name
}

# Cert-Manager Module
# Used alongside the Let's Encrypt Cluster Issuer Module to automate certificate management
module "cert_manager" {
  source          = "./modules/helm/cert-manager"
  namespace       = "cert-manager"
  chart_version   = "v1.17.0"
  install_crds    = true
}

# Let's Encrypt Cluster Issuer Module
# Used to configure a ClusterIssuer for Let's Encrypt, enabling automatic certificate issuance and renewal
module "letsencrypt_cluster_issuer" {
  source                 = "./modules/helm/cert-manager-cluster-issuer"
  namespace              = "cert-manager"
  email                  = var.email
  acme_server            = "https://acme-v02.api.letsencrypt.org/directory"
  dns_provider           = "cloudflare"
  cloudflare_api_token   = var.cloudflare_api_token
  cloudflare_zone_id     = var.cloudflare_zone_id
}

# Certificate Module
# Used to create a Certificate resource for a specific domain
module "certificate" {
  source     = "./modules/kubernetes_manifests/certificate"
  namespace  = "cert-manager"
  domain     = var.domain
}

# ======================================================================
# Solutions
# These modules are used to deploy specific applications or services
# ======================================================================

# Games Module
module "games" {
  source              = "./modules/_solutions/games"
  resource_group      = azurerm_resource_group.rg.name
  location            = var.location
  storage_account_name = "gamesstorage"
  storage_share_name   = "games"
  tls_secret_name      = module.certificate.tls_secret_name
  domain              = "games.${var.domain}"
}
