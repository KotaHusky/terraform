variable "storage_account_name" {}
variable "storage_share_name" {}
variable "resource_group" {}
variable "location" {}
variable "namespace" {}

resource "random_id" "storage_suffix" {
  byte_length = 8
}

resource "azurerm_storage_account" "storage" {
  name                     = "${var.storage_account_name}${random_id.storage_suffix.hex}"
  resource_group_name      = var.resource_group
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "storage" {
  name                 = var.storage_share_name
  storage_account_id = azurerm_storage_account.storage.id
  quota               = 10
}

resource "kubernetes_persistent_volume" "storage" {
  metadata {
    name = var.storage_share_name
  }
  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      azure_file {
        secret_name = "azure-secret"
        share_name  = azurerm_storage_share.storage.name
        read_only   = false
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "storage" {
  metadata {
    name      = var.storage_share_name
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

output "pvc_name" {
  value = kubernetes_persistent_volume_claim.storage.metadata[0].name
}
