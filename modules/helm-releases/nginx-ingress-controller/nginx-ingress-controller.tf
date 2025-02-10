variable "namespace" {
  description = "The namespace to deploy the NGINX Ingress Controller"
  type        = string
  default     = "ingress-nginx"
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

resource "kubernetes_service_account" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress-serviceaccount"
    namespace = var.namespace
  }
}

resource "kubernetes_role" "nginx_ingress_role" {
  metadata {
    name      = "nginx-ingress-role"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "endpoints", "pods", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }
}

resource "kubernetes_role_binding" "nginx_ingress_rolebinding" {
  metadata {
    name      = "nginx-ingress-rolebinding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.nginx_ingress_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.nginx_ingress.metadata[0].name
    namespace = var.namespace
  }
}

resource "helm_release" "nginx_ingress" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.6"
  timeout    = 180 # 3 minutes timeout for Helm release
  cleanup_on_fail = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Tells AKS to look for the static IP in your main RG
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = var.resource_group_name
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "false"
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

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account.nginx_ingress.metadata[0].name
  }

  set {
    name = "rbac.create"
    value = "true"
  }
}