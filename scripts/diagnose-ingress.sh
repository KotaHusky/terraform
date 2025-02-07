#!/bin/bash

# Variables
RESOURCE_GROUP="aks-shared"
AKS_CLUSTER="aks-shared-cluster"
NAMESPACE="webapps"
INGRESS_CONTROLLER_NAMESPACE="kube-system"
INGRESS_CONTROLLER_NAME="ingress-nginx"
INGRESS_RESOURCE_NAME="homepage-ingress"
SERVICE_NAME="homepage"
DNS_NAME="dev.kota.dog"
MANAGED_RG="MC_${RESOURCE_GROUP}_${AKS_CLUSTER}_eastus"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check the network plugin configuration
echo -e "${YELLOW}Checking the network plugin configuration...${NC}"
echo "az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query 'networkProfile.networkPlugin' -o tsv"
NETWORK_PLUGIN=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query 'networkProfile.networkPlugin' -o tsv)
if [ "$NETWORK_PLUGIN" != "kubenet" ]; then
  echo -e "${RED}Network plugin is not set to kubenet. Current network plugin: $NETWORK_PLUGIN.${NC}"
  exit 1
else
  echo -e "${GREEN}Network plugin is set to kubenet.${NC}"
fi

# Check the status of the ingress controller pods
echo -e "${YELLOW}Checking the status of the ingress controller pods...${NC}"
echo "kubectl get pods -n $INGRESS_CONTROLLER_NAMESPACE -l app.kubernetes.io/name=$INGRESS_CONTROLLER_NAME"
if ! kubectl get pods -n $INGRESS_CONTROLLER_NAMESPACE -l app.kubernetes.io/name=$INGRESS_CONTROLLER_NAME &> /dev/null; then
  echo -e "${RED}Ingress controller pods are not running. Please check the ingress controller deployment.${NC}"
  exit 1
else
  echo -e "${GREEN}Ingress controller pods are running.${NC}"
fi

# Check the ingress resource configuration
echo -e "${YELLOW}Checking the ingress resource configuration...${NC}"
echo "kubectl get ingress $INGRESS_RESOURCE_NAME -n $NAMESPACE"
if ! kubectl get ingress $INGRESS_RESOURCE_NAME -n $NAMESPACE &> /dev/null; then
  echo -e "${RED}Ingress resource $INGRESS_RESOURCE_NAME not found in namespace $NAMESPACE.${NC}"
  exit 1
else
  echo -e "${GREEN}Ingress resource $INGRESS_RESOURCE_NAME found.${NC}"
fi

# Check the status of the service backing the ingress
echo -e "${YELLOW}Checking the status of the service backing the ingress...${NC}"
echo "kubectl get service $SERVICE_NAME -n $NAMESPACE"
if ! kubectl get service $SERVICE_NAME -n $NAMESPACE &> /dev/null; then
  echo -e "${RED}Service $SERVICE_NAME not found in namespace $NAMESPACE.${NC}"
  exit 1
else
  echo -e "${GREEN}Service $SERVICE_NAME found.${NC}"
fi

# Check DNS resolution
echo -e "${YELLOW}Checking DNS resolution for $DNS_NAME...${NC}"
echo "nslookup $DNS_NAME"
if ! nslookup $DNS_NAME &> /dev/null; then
  echo -e "${RED}DNS name $DNS_NAME does not resolve. Please check your DNS configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}DNS name $DNS_NAME resolves correctly.${NC}"
fi

# Retrieve the NSG name dynamically
echo -e "${YELLOW}Retrieving the Network Security Group (NSG) name...${NC}"
echo "az network nsg list --resource-group $MANAGED_RG --query \"[0].name\" -o tsv"
NSG_NAME=$(az network nsg list --resource-group $MANAGED_RG --query "[0].name" -o tsv)
if [ -z "$NSG_NAME" ]; then
  echo -e "${RED}Failed to retrieve the NSG name. Please check your resource group and NSG configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}Retrieved NSG name: $NSG_NAME${NC}"
fi

# Check Network Security Groups (NSGs)
echo -e "${YELLOW}Checking Network Security Groups (NSGs)...${NC}"
echo "az network nsg rule list --resource-group $MANAGED_RG --nsg-name $NSG_NAME --include-default --output table"
NSG_RULES=$(az network nsg rule list --resource-group $MANAGED_RG --nsg-name $NSG_NAME --include-default --output table)
if ! echo "$NSG_RULES" | grep -q "AllowAzureLoadBalancerInBound"; then
  echo -e "${RED}NSG does not allow traffic from Azure Load Balancer. Please check your NSG rules.${NC}"
else
  echo -e "${GREEN}NSG allows traffic from Azure Load Balancer.${NC}"
fi
echo "$NSG_RULES"

# Retrieve the Load Balancer name dynamically
echo -e "${YELLOW}Retrieving the Load Balancer name...${NC}"
echo "az network lb list --resource-group $MANAGED_RG --query \"[0].name\" -o tsv"
LB_NAME=$(az network lb list --resource-group $MANAGED_RG --query "[0].name" -o tsv)
if [ -z "$LB_NAME" ]; then
  echo -e "${RED}Failed to retrieve the Load Balancer name. Please check your resource group and Load Balancer configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}Retrieved Load Balancer name: $LB_NAME${NC}"
fi

# Check Load Balancer rules
echo -e "${YELLOW}Checking Load Balancer rules...${NC}"
echo "az network lb rule list --resource-group $MANAGED_RG --lb-name $LB_NAME --output table"
LB_RULES=$(az network lb rule list --resource-group $MANAGED_RG --lb-name $LB_NAME --output table)
if ! echo "$LB_RULES" | grep -q "80"; then
  echo -e "${RED}Load Balancer does not have a rule for port 80. Please check your Load Balancer configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}Load Balancer has a rule for port 80.${NC}"
fi

# Check pod logs
# echo -e "${YELLOW}Checking logs for the application pods...${NC}"
# POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=homepage -o jsonpath="{.items[0].metadata.name}")
# echo "kubectl logs -n $NAMESPACE $POD_NAME"
# kubectl logs -n $NAMESPACE $POD_NAME

# Check ingress controller logs
echo -e "${YELLOW}Checking logs for the ingress controller...${NC}"
INGRESS_POD_NAME=$(kubectl get pods -n $INGRESS_CONTROLLER_NAMESPACE -l app.kubernetes.io/name=$INGRESS_CONTROLLER_NAME -o jsonpath="{.items[0].metadata.name}")

if [ -z "$INGRESS_POD_NAME" ]; then
  echo -e "${RED}No ingress controller pod found. Please check the ingress controller deployment.${NC}"
else
  echo "kubectl logs -n $INGRESS_CONTROLLER_NAMESPACE $INGRESS_POD_NAME --tail=50"
  kubectl logs -n $INGRESS_CONTROLLER_NAMESPACE $INGRESS_POD_NAME --tail=50
fi

# Check service endpoints
echo -e "${YELLOW}Checking service endpoints...${NC}"
echo "kubectl get endpoints $SERVICE_NAME -n $NAMESPACE"
kubectl get endpoints $SERVICE_NAME -n $NAMESPACE

# Check ingress annotations
echo -e "${YELLOW}Checking ingress annotations...${NC}"
echo "kubectl describe ingress $INGRESS_RESOURCE_NAME -n $NAMESPACE"
kubectl describe ingress $INGRESS_RESOURCE_NAME -n $NAMESPACE

echo -e "${GREEN}All checks completed.${NC}"