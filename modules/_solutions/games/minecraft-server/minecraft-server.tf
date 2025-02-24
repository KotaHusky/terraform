variable "namespace" {
  type    = string
  default = "games"
}

variable "pvc_name" {
  description = "The name of the Persistent Volume Claim"
  type        = string
  default     = "minecraft-pvc"
}

variable "tls_secret_name" {
  description = "The name of the TLS secret"
  type        = string
}

variable "domain" {
  type        = string
}

variable "deployment_version" {
  description = "A version number to force recreation of the deployment"
  type        = string
  default     = "1"
}

resource "random_id" "deployment_suffix" {
  byte_length = 4
  keepers = {
    version = var.deployment_version
  }
}

resource "random_id" "pvc_suffix" {
  byte_length = 4
  keepers = {
    version = var.deployment_version
  }
}

resource "kubernetes_persistent_volume_claim" "minecraft" {
  metadata {
    name      = "${var.pvc_name}-${random_id.pvc_suffix.hex}"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "3Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "minecraft" {
  timeouts {
    create = "3m"
  }
  metadata {
    name      = "minecraft-${random_id.deployment_suffix.hex}"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    # Use RollingUpdate strategy to ensure PVC is only attached to one pod at a time
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }
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

          # Required to run the container
          env {
            name  = "EULA"
            value = "TRUE"
          }

          port {
            container_port = 25565
          }

          volume_mount {
            mount_path = "/data"
            name       = "minecraft-storage"
          }
        }
        volume {
          name = "minecraft-storage"
          persistent_volume_claim {
            claim_name = "${var.pvc_name}-${random_id.pvc_suffix.hex}"
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

resource "kubernetes_ingress_v1" "minecraft" {
  metadata {
    name      = "minecraft"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/ingress.class"       = "nginx"
      "cert-manager.io/cluster-issuer"    = "letsencrypt-dns"
    }
  }

  spec {
    ingress_class_name = "nginx"
    tls {
      hosts      = ["minecraft.${var.domain}"]
      secret_name = var.tls_secret_name
    }
    rule {
      host = "minecraft.${var.domain}"
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.minecraft.metadata[0].name
              port {
                number = 25565
              }
            }
          }
        }
      }
    }
  }
}