variable "namespace" {
  description = "The namespace to install cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "email" {
  description = "The email address for the ACME account"
  type        = string
}

variable "acme_server" {
  description = "The ACME server URL"
  type        = string
}

variable "dns_provider" {
  description = "The DNS provider for DNS-01 challenges"
  type        = string
  default     = "cloudflare"
}

variable "cloudflare_api_token" {
  description = "The API token for Cloudflare"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "The Zone ID for the Cloudflare domain"
  type        = string
}

# Create the Kubernetes secret to store the Cloudflare API token
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = var.namespace
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  type = "Opaque"
}

resource "helm_release" "cluster_issuer" {
  depends_on = [kubernetes_secret.cloudflare_api_token]

  name       = "cert-manager-cluster-issuer"
  namespace  = var.namespace
  repository = "local"
  chart      = "./modules/helm/cert-manager-cluster-issuer"
  version    = "0.1.0"

  set {
    name  = "email"
    value = var.email
  }

  set {
    name  = "acme_server"
    value = var.acme_server
  }

  set {
    name  = "dns_provider"
    value = var.dns_provider
  }

  set {
    name  = "dns_credentials_secret"
    value = "cloudflare-api-token-secret"
  }

  set {
    name  = "cloudflare_zone_id"
    value = var.cloudflare_zone_id
  }
}