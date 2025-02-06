variable "namespace" {
  description = "The namespace to deploy the NGINX Ingress Controller"
  type        = string
  default     = "kube-system"
}

variable "replica_count" {
  description = "The number of replicas for the NGINX Ingress Controller"
  type        = number
  default     = 2
}

variable "load_balancer_ip" {
  description = "The static IP address for the NGINX Ingress Controller"
  type        = string
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = var.namespace
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.6"
  timeout = 480 # Longer timeout for Helm release

  set {
    name  = "controller.replicaCount"
    value = var.replica_count
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
    value = var.load_balancer_ip
  }

    set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }
}

output "nginx_ingress_status" {
  value = helm_release.nginx_ingress.status
}