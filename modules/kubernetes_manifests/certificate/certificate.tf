variable "namespace" {
  description = "The namespace to create the certificate"
  type        = string
  default     = "cert-manager"
}

variable "domain" {
  description = "The domain name for the certificate"
  type        = string
}

resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "wildcard-${var.domain}-tls"
      namespace = var.namespace
    }
    spec = {
      secretName = "wildcard-${var.domain}-tls"
      issuerRef = {
        name = "letsencrypt-dns"
        kind = "ClusterIssuer"
      }
      commonName = "*.${var.domain}"
      dnsNames = [
        "*.${var.domain}",
        "${var.domain}"
      ]
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "tls_secret_name" {
  value = kubernetes_manifest.certificate.manifest.spec.secretName
}