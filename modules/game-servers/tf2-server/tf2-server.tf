resource "kubernetes_namespace" "gaming" {
  metadata {
    name = "gaming"
  }
}

resource "kubernetes_deployment" "tf2_server" {
  metadata {
    name      = "tf2-server"
    namespace = kubernetes_namespace.gaming.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "tf2-server"
      }
    }
    template {
      metadata {
        labels = {
          app = "tf2-server"
        }
      }
      spec {
        container {
          name  = "tf2-server"
          image = "cm2network/tf2:latest"
          port {
            container_port = 27015
            protocol       = "UDP"
          }
          port {
            container_port = 27015
            protocol       = "TCP"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "tf2_server" {
  metadata {
    name      = "tf2-server"
    namespace = kubernetes_namespace.gaming.metadata[0].name
  }
  spec {
    type = "LoadBalancer"
    port {
      port        = 27015
      target_port = 27015
      protocol    = "UDP"
    }
    port {
      port        = 27015
      target_port = 27015
      protocol    = "TCP"
    }
    selector = {
      app = "tf2-server"
    }
  }
}

resource "kubernetes_network_policy" "allow_tf2_server" {
  metadata {
    name      = "allow-tf2-server"
    namespace = kubernetes_namespace.gaming.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = {
        app = "tf2-server"
      }
    }
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "gaming"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = 27015
      }
      ports {
        protocol = "TCP"
        port     = 27015
      }
    }
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "gaming"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = 27015
      }
      ports {
        protocol = "TCP"
        port     = 27015
      }
    }
  }
}

output "namespace" {
  value = kubernetes_namespace.gaming.metadata[0].name
}