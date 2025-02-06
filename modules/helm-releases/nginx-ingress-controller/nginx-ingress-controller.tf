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

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  
}

variable "name" {
  description = "The name of the Helm release"
  type        = string
  default     = "nginx-ingress"
}

resource "helm_release" "nginx_ingress" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.6"
  timeout = 900 # 15 minutes timeout for Helm release
  cleanup_on_fail = true

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = var.resource_group_name
  }

  set {
    name  = "controller.replicaCount"
    value = var.replica_count
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
}