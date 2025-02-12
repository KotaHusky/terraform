variable "storage_account_name" {
  description = "The name of the storage account."
  type        = string
}

variable "storage_share_name" {
  description = "The name of the storage share."
  type        = string
}

variable "resource_group" {
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
  resource_group       = var.resource_group
  location             = var.location
  namespace            = kubernetes_namespace.games.metadata[0].name
}

resource "kubernetes_persistent_volume_claim" "games_storage_claim" {
  metadata {
    name      = "games-storage-claim"
    namespace = kubernetes_namespace.games.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
  }
}

## Games

### Minecraft Server
module "minecraft_server" {
  source               = "./minecraft-server"
  namespace            = kubernetes_namespace.games.metadata[0].name
  storage_account_name = var.storage_account_name
  storage_share_name   = var.storage_share_name
  resource_group       = var.resource_group
  location             = var.location
  tls_secret_name      = var.tls_secret_name
  pvc_name             = kubernetes_persistent_volume_claim.games_storage_claim.metadata[0].name
  domain               = "minecraft.${var.domain}"
}

resource "kubernetes_service" "minecraft" {
  metadata {
    name      = "minecraft"
    namespace = kubernetes_namespace.games.metadata[0].name
  }
  spec {
    selector = {
      app = "minecraft"
    }
    port {
      port        = 25565
      target_port = 25565
    }
  }
}

resource "kubernetes_ingress" "minecraft" {
  metadata {
    name      = "minecraft"
    namespace = kubernetes_namespace.games.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns"
    }
  }
  spec {
    tls {
      hosts      = ["minecraft.${var.domain}"]
      secret_name = var.tls_secret_name
    }
    rule {
      host = "minecraft.${var.domain}"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.minecraft.metadata[0].name
            service_port = 25565
          }
        }
      }
    }
  }
}