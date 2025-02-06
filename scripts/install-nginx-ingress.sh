#!/bin/bash

# Load variables from .tfvars file
TFVARS_FILE="terraform.tfvars"
LOAD_BALANCER_IP=$(grep 'load_balancer_ip' $TFVARS_FILE | cut -d '=' -f2 | tr -d ' "')

# Check if the public IP is set
if [ -z "$LOAD_BALANCER_IP" ]; then
  echo "Error: load_balancer_ip is not set in $TFVARS_FILE"
  exit 1
fi

# Add the Ingress-Nginx Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install or upgrade the Nginx Ingress Controller
helm upgrade --install nginx-ingress-31e941f9 ingress-nginx/ingress-nginx \
  --namespace kube-system \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.service.loadBalancerIP=$LOAD_BALANCER_IP \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.limits.cpu=200m

echo "Nginx Ingress Controller installed successfully."