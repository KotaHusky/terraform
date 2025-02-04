#!/bin/bash

# Variables
RESOURCE_GROUP="aks-shared"
AKS_CLUSTER="aks-shared-prod-cluster"
NAMESPACE="webapps"
INGRESS_NAME="homepage-ingress"
SERVICE_NAME="homepage"
INGRESS_CONTROLLER_NAMESPACE="kube-system"
INGRESS_CONTROLLER_NAME="nginx-ingress"

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

# Check if the ingress resource exists
echo -e "${YELLOW}Checking if the ingress resource exists...${NC}"
if ! kubectl get ingress $INGRESS_NAME -n $NAMESPACE &> /dev/null; then
  echo -e "${RED}Ingress resource $INGRESS_NAME does not exist in namespace $NAMESPACE.${NC}"
  exit 1
fi

# Check the status of the ingress resource
echo -e "${YELLOW}Checking the status of the ingress resource...${NC}"
INGRESS_STATUS=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$INGRESS_STATUS" ]; then
  echo -e "${RED}Ingress resource $INGRESS_NAME is not properly configured. No IP address assigned.${NC}"
  exit 1
else
  echo -e "${GREEN}Ingress resource $INGRESS_NAME is properly configured with IP address: $INGRESS_STATUS${NC}"
fi

# Check if the associated service is running
echo -e "${YELLOW}Checking if the associated service is running...${NC}"
if ! kubectl get service $SERVICE_NAME -n $NAMESPACE &> /dev/null; then
  echo -e "${RED}Service $SERVICE_NAME does not exist in namespace $NAMESPACE.${NC}"
  exit 1
fi

# Check the status of the ingress controller
echo -e "${YELLOW}Checking the status of the ingress controller...${NC}"
if ! kubectl get pods -n $INGRESS_CONTROLLER_NAMESPACE -l app.kubernetes.io/name=$INGRESS_CONTROLLER_NAME &> /dev/null; then
  echo -e "${RED}Ingress controller $INGRESS_CONTROLLER_NAME is not running in namespace $INGRESS_CONTROLLER_NAMESPACE.${NC}"
  exit 1
fi

echo -e "${GREEN}Ingress controller $INGRESS_CONTROLLER_NAME is running in namespace $INGRESS_CONTROLLER_NAMESPACE.${NC}"

# Check if the ingress controller pods are healthy
echo -e "${YELLOW}Checking the health of the ingress controller pods...${NC}"
kubectl get pods -n $INGRESS_CONTROLLER_NAMESPACE -l app.kubernetes.io/name=$INGRESS_CONTROLLER_NAME -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' | while read pod status; do
  if [ "$status" != "Running" ]; then
    echo -e "${RED}Ingress controller pod $pod is not running. Status: $status${NC}"
    exit 1
  fi
done

echo -e "${GREEN}All ingress controller pods are running.${NC}"

# Check if the ingress resource is accessible
echo -e "${YELLOW}Checking if the ingress resource is accessible...${NC}"
curl -I http://$INGRESS_STATUS &> /dev/null
if [ $? -ne 0 ]; then
  echo -e "${RED}Ingress resource $INGRESS_NAME is not accessible at IP address: $INGRESS_STATUS${NC}"
  exit 1
else
  echo -e "${GREEN}Ingress resource $INGRESS_NAME is accessible at IP address: $INGRESS_STATUS${NC}"
fi

echo -e "${GREEN}Ingress verification completed successfully.${NC}"