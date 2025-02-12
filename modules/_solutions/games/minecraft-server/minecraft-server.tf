variable "namespace" {
  type    = string
  default = "games"
}

variable "storage_account_name" {}
variable "storage_share_name" {}
variable "resource_group" {}
variable "location" {}
variable "tls_secret_name" {
  description = "The name of the TLS secret"
  type        = string
}
variable "pvc_name" {
  description = "The name of the Persistent Volume Claim"
  type        = string
}
variable "domain" {
  type        = string
}

resource "kubernetes_deployment" "minecraft" {
  metadata {
    name      = "minecraft"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "minecraft"
      }
    }
    template {
      metadata {
        labels = {
          app = "minecraft"
        }
      }
      spec {
        container {
          name  = "minecraft"
          image = "itzg/minecraft-server"
          port {
            container_port = 25565
          }
          volume_mount {
            mount_path = "/data"
            name       = "games-storage"
          }
        }
        volume {
          name = "games-storage"
          persistent_volume_claim {
            claim_name = var.pvc_name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "minecraft" {
  metadata {
    name      = "minecraft"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "minecraft"
    }
    port {
      port        = 25565
      target_port = 25565
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress" "minecraft" {
  metadata {
    name      = "minecraft"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = "letsencrypt-dns"
    }
  }
  spec {
    tls {
      hosts      = ["minecraft.games.kota.dog"]
      secret_name = var.tls_secret_name
    }
    rule {
      host = "minecraft.games.kota.dog"
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