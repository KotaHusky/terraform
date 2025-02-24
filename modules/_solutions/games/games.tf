variable "storage_account_name" {
  description = "The name of the storage account."
  type        = string
}

variable "storage_share_name" {
  description = "The name of the storage share."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "location" {
  description = "The location of the resources."
  type        = string
}

variable "tls_secret_name" {
  description = "The name of the TLS secret."
  type        = string
}

variable "domain" {
  type        = string
}

resource "kubernetes_namespace" "games" {
  metadata {
    name = "games"
  }
}

module "games_storage" {
  source               = "../../azure/storage"
  storage_account_name = var.storage_account_name
  storage_share_name   = var.storage_share_name
  resource_group_name       = var.resource_group_name
  location             = var.location
  namespace            = kubernetes_namespace.games.metadata[0].name
}

## Games

### Minecraft Server
module "minecraft_server" {
  source               = "./minecraft-server"
  namespace            = kubernetes_namespace.games.metadata[0].name
  pvc_name             = "minecraft-pvc"
  tls_secret_name      = var.tls_secret_name
  domain               = var.domain
}
