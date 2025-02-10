#!/bin/bash

# Variables
RESOURCE_GROUP="aks-shared"
AKS_CLUSTER="aks-shared-cluster"
NAMESPACE="cert-manager"
CERT_NAMESPACE="webapps"
CLUSTER_ISSUER_NAME="letsencrypt-dns"
DNS_NAME="kota.dog"
CERTIFICATE_NAME="wildcard-${DNS_NAME}-tls"
MANAGED_RG="MC_${RESOURCE_GROUP}_${AKS_CLUSTER}_eastus"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Clear the terminal for cleaner output
clear

# Update kubectl context using Azure CLI
echo -e "${YELLOW}Updating kubectl context using Azure CLI...${NC}"
echo "az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing"
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing

# Check if we can connect to the Kubernetes cluster
echo -e "${YELLOW}Checking Kubernetes cluster connectivity...${NC}"
echo "kubectl cluster-info"
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}Unable to connect to the Kubernetes cluster. Please check your Kubernetes context.${NC}"
  exit 1
else
  echo -e "${GREEN}Connected to the Kubernetes cluster.${NC}"
fi

# Check the status of cert-manager pods
echo -e "${YELLOW}Checking the status of cert-manager pods...${NC}"
echo "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=cert-manager"
if ! kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=cert-manager &> /dev/null; then
  echo -e "${RED}cert-manager pods are not running. Please check the cert-manager deployment.${NC}"
  exit 1
else
  echo -e "${GREEN}cert-manager pods are running.${NC}"
fi

# Check the ClusterIssuer configuration
echo -e "${YELLOW}Checking the ClusterIssuer configuration...${NC}"
echo "kubectl get clusterissuer $CLUSTER_ISSUER_NAME -o yaml"
if ! kubectl get clusterissuer $CLUSTER_ISSUER_NAME -o yaml &> /dev/null; then
  echo -e "${RED}ClusterIssuer $CLUSTER_ISSUER_NAME not found.${NC}"
  exit 1
else
  echo -e "${GREEN}ClusterIssuer $CLUSTER_ISSUER_NAME found.${NC}"
fi

# Check the status of the ClusterIssuer
echo -e "${YELLOW}Checking the status of the ClusterIssuer...${NC}"
CLUSTER_ISSUER_STATUS=$(kubectl get clusterissuer $CLUSTER_ISSUER_NAME -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}")
if [ "$CLUSTER_ISSUER_STATUS" != "True" ]; then
  echo -e "${RED}ClusterIssuer $CLUSTER_ISSUER_NAME is not ready.${NC}"
  exit 1
else
  echo -e "${GREEN}ClusterIssuer $CLUSTER_ISSUER_NAME is ready.${NC}"
fi

# List all certificates in the specified namespace
echo -e "${YELLOW}Listing all certificates in namespace $CERT_NAMESPACE...${NC}"
echo "kubectl get certificates -n $CERT_NAMESPACE"
kubectl get certificates -n $CERT_NAMESPACE

# Check the Certificate resource configuration
echo -e "${YELLOW}Checking the Certificate resource configuration...${NC}"
echo "kubectl get certificate $CERTIFICATE_NAME -n $CERT_NAMESPACE -o yaml"
if ! kubectl get certificate $CERTIFICATE_NAME -n $CERT_NAMESPACE -o yaml &> /dev/null; then
  echo -e "${RED}Certificate $CERTIFICATE_NAME not found in namespace $CERT_NAMESPACE.${NC}"
  exit 1
else
  echo -e "${GREEN}Certificate $CERTIFICATE_NAME found.${NC}"
fi

# Check the status of the Certificate
echo -e "${YELLOW}Checking the status of the Certificate...${NC}"
CERTIFICATE_STATUS=$(kubectl get certificate $CERTIFICATE_NAME -n $CERT_NAMESPACE -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}")
if [ "$CERTIFICATE_STATUS" != "True" ]; then
  echo -e "${RED}Certificate $CERTIFICATE_NAME is not ready.${NC}"
  echo -e "${YELLOW}Checking events related to the Certificate...${NC}"
  echo "kubectl get events -n $CERT_NAMESPACE --field-selector involvedObject.name=$CERTIFICATE_NAME"
  kubectl get events -n $CERT_NAMESPACE --field-selector involvedObject.name=$CERTIFICATE_NAME
  echo -e "${YELLOW}Checking cert-manager logs...${NC}"
  echo "kubectl logs -l app.kubernetes.io/name=cert-manager -n $NAMESPACE"
  kubectl logs -l app.kubernetes.io/name=cert-manager -n $NAMESPACE
  exit 1
else
  echo -e "${GREEN}Certificate $CERTIFICATE_NAME is ready.${NC}"
fi

# Check the expiration date of the Certificate
echo -e "${YELLOW}Checking the expiration date of the Certificate...${NC}"
CERTIFICATE_EXPIRATION=$(kubectl get certificate $CERTIFICATE_NAME -n $CERT_NAMESPACE -o jsonpath="{.status.notAfter}")
echo -e "${GREEN}Certificate $CERTIFICATE_NAME expires on $CERTIFICATE_EXPIRATION.${NC}"

# Check the secret associated with the Certificate
echo -e "${YELLOW}Checking the secret associated with the Certificate...${NC}"
SECRET_NAME=$(kubectl get certificate $CERTIFICATE_NAME -n $CERT_NAMESPACE -o jsonpath="{.spec.secretName}")
echo "kubectl get secret $SECRET_NAME -n $CERT_NAMESPACE"
if ! kubectl get secret $SECRET_NAME -n $CERT_NAMESPACE &> /dev/null; then
  echo -e "${RED}Secret $SECRET_NAME not found in namespace $CERT_NAMESPACE.${NC}"
  exit 1
else
  echo -e "${GREEN}Secret $SECRET_NAME found.${NC}"
fi

# Check events related to the Certificate
echo -e "${YELLOW}Checking events related to the Certificate...${NC}"
echo "kubectl get events -n $CERT_NAMESPACE --field-selector involvedObject.name=$CERTIFICATE_NAME"
kubectl get events -n $CERT_NAMESPACE --field-selector involvedObject.name=$CERTIFICATE_NAME

# Check the CertificateRequest resource
echo -e "${YELLOW}Checking the CertificateRequest resource...${NC}"
CERTIFICATE_REQUEST_NAME=$(kubectl get certificaterequest -n $CERT_NAMESPACE -o jsonpath="{.items[?(@.metadata.annotations['cert-manager.io/certificate-name']=='$CERTIFICATE_NAME')].metadata.name}")
echo "kubectl get certificaterequest $CERTIFICATE_REQUEST_NAME -n $CERT_NAMESPACE -o yaml"
kubectl get certificaterequest $CERTIFICATE_REQUEST_NAME -n $CERT_NAMESPACE -o yaml

# Perform curl tests to verify the certificate
echo -e "${YELLOW}Performing curl tests to verify the certificate...${NC}"
CURL_TIMEOUT=3

# Test HTTPS endpoint
echo "curl -m $CURL_TIMEOUT -vk https://$DNS_NAME/"
HTTPS_STATUS=$(curl -m $CURL_TIMEOUT -vk https://$DNS_NAME/ 2>&1)
if echo "$HTTPS_STATUS" | grep -q "SSL certificate verify ok."; then
  echo -e "${GREEN}HTTPS endpoint is accessible and the certificate is valid.${NC}"
else
  echo -e "${RED}HTTPS endpoint is not accessible or the certificate is invalid.${NC}"
fi

echo -e "${GREEN}All checks completed.${NC}"