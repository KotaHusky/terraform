#!/bin/bash

# Variables
RESOURCE_GROUP="aks-shared"
APP_GATEWAY_NAME="aks-shared-app-gateway"
NAMESPACE="webapps"
INGRESS_NAME="homepage-ingress"
SERVICE_NAME="homepage"
AGIC_NAMESPACE="kube-system"
AKS_CLUSTER="aks-shared-prod-cluster"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Update kubectl context using Azure CLI
echo -e "${YELLOW}Updating kubectl context using Azure CLI...${NC}"
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing

# Check if we can connect to the Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}Unable to connect to the Kubernetes cluster. Please check your Kubernetes context.${NC}"
  exit 1
fi

# Check if AGIC addon is enabled
echo -e "${YELLOW}Checking if AGIC addon is enabled...${NC}"
AGIC_ADDON_ENABLED=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query "addonProfiles.ingressApplicationGateway.enabled" -o tsv)
if [ "$AGIC_ADDON_ENABLED" != "true" ]; then
  echo -e "${RED}AGIC addon is not enabled. Please enable the AGIC addon.${NC}"
  exit 1
fi

# Check the Backend Pool Configuration
echo -e "${YELLOW}Checking the Backend Pool Configuration...${NC}"
BACKEND_POOL=$(az network application-gateway address-pool show --resource-group $RESOURCE_GROUP --gateway-name $APP_GATEWAY_NAME --name dynamicPool)
BACKEND_ADDRESSES=$(echo $BACKEND_POOL | jq '.backendAddresses')
if [ "$BACKEND_ADDRESSES" == "[]" ]; then
  echo -e "${RED}Warning: Backend addresses are empty. Please check your backend pool configuration.${NC}"
else
  echo $BACKEND_POOL
fi

# Check the Health Probes
echo -e "${YELLOW}Checking the Health Probes...${NC}"
az network application-gateway probe list --resource-group $RESOURCE_GROUP --gateway-name $APP_GATEWAY_NAME

# Check the Backend HTTP Settings
echo -e "${YELLOW}Checking the Backend HTTP Settings...${NC}"
az network application-gateway http-settings list --resource-group $RESOURCE_GROUP --gateway-name $APP_GATEWAY_NAME

# Check the Backend Service
echo -e "${YELLOW}Checking the Backend Service...${NC}"
kubectl get pods -n $NAMESPACE
echo
kubectl describe service $SERVICE_NAME -n $NAMESPACE
echo
kubectl describe pod -l app=$SERVICE_NAME -n $NAMESPACE
echo
kubectl logs -l app=$SERVICE_NAME -n $NAMESPACE

# Check the Ingress Controller Logs
echo -e "${YELLOW}Checking the Ingress Controller Logs...${NC}"
kubectl logs -l app=ingress-appgw-deployment -n $AGIC_NAMESPACE

# Verify the Ingress Resource
echo -e "${YELLOW}Verifying the Ingress Resource...${NC}"
kubectl get ingress -n $NAMESPACE
echo
kubectl describe ingress $INGRESS_NAME -n $NAMESPACE

echo -e "${GREEN}Diagnosis script finished.${NC}"