#!/bin/bash

# Variables
RESOURCE_GROUP="aks-shared"
AKS_CLUSTER="aks-shared-cluster"
NAMESPACE="webapps"
INGRESS_CONTROLLER_NAMESPACE="ingress-nginx"
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

# Check Load Balancer frontend IP configuration
echo -e "${YELLOW}Checking Load Balancer frontend IP configuration...${NC}"
echo "az network lb frontend-ip list --resource-group $MANAGED_RG --lb-name $LB_NAME --output table"
LB_FRONTEND_IPS=$(az network lb frontend-ip list --resource-group $MANAGED_RG --lb-name $LB_NAME --output table)
if [ -z "$LB_FRONTEND_IPS" ]; then
  echo -e "${RED}Load Balancer does not have a frontend IP configuration. Please check your Load Balancer configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}Load Balancer has a frontend IP configuration.${NC}"
fi
echo "$LB_FRONTEND_IPS"

# Check Load Balancer backend pools
echo -e "${YELLOW}Checking Load Balancer backend pools...${NC}"
echo "az network lb address-pool list --resource-group $MANAGED_RG --lb-name $LB_NAME --output table"
LB_BACKEND_POOLS=$(az network lb address-pool list --resource-group $MANAGED_RG --lb-name $LB_NAME --output table)
if [ -z "$LB_BACKEND_POOLS" ]; then
  echo -e "${RED}Load Balancer does not have backend pools configured. Please check your Load Balancer configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}Load Balancer has backend pools configured.${NC}"
fi
echo "$LB_BACKEND_POOLS"

# Check Load Balancer health probes
echo -e "${YELLOW}Checking Load Balancer health probes...${NC}"
echo "az network lb probe list --resource-group $MANAGED_RG --lb-name $LB_NAME --output table"
LB_HEALTH_PROBES=$(az network lb probe list --resource-group $MANAGED_RG --lb-name $LB_NAME --output table)
if [ -z "$LB_HEALTH_PROBES" ]; then
  echo -e "${RED}Load Balancer does not have health probes configured. Please check your Load Balancer configuration.${NC}"
  exit 1
else
  echo -e "${GREEN}Load Balancer has health probes configured.${NC}"
fi
echo "$LB_HEALTH_PROBES"

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

# Check Role and RoleBinding
echo -e "${YELLOW}Checking Role and RoleBinding for NGINX Ingress Controller...${NC}"
echo "kubectl get role nginx-ingress-role -n $INGRESS_CONTROLLER_NAMESPACE -o yaml"
kubectl get role nginx-ingress-role -n $INGRESS_CONTROLLER_NAMESPACE -o yaml

echo "kubectl get rolebinding nginx-ingress-rolebinding -n $INGRESS_CONTROLLER_NAMESPACE -o yaml"
kubectl get rolebinding nginx-ingress-rolebinding -n $INGRESS_CONTROLLER_NAMESPACE -o yaml

# Perform curl tests
echo -e "${YELLOW}Performing curl tests...${NC}"
CURL_TIMEOUT=3

# Test root endpoint
echo "curl -m $CURL_TIMEOUT -s -o /dev/null -w \"%{http_code}\" http://$DNS_NAME/"
ROOT_STATUS=$(curl -m $CURL_TIMEOUT -s -o /dev/null -w "%{http_code}" http://$DNS_NAME/)
if [ "$ROOT_STATUS" -eq 200 ]; then
  echo -e "${GREEN}Root endpoint is accessible.${NC}"
else
  echo -e "${RED}Root endpoint is not accessible. HTTP status code: $ROOT_STATUS.${NC}"
fi

# Test health endpoint
echo "curl -m $CURL_TIMEOUT -s -o /dev/null -w \"%{http_code}\" http://$DNS_NAME/api/health"
HEALTH_STATUS=$(curl -m $CURL_TIMEOUT -s -o /dev/null -w "%{http_code}" http://$DNS_NAME/api/health)
if [ "$HEALTH_STATUS" -eq 200 ]; then
  echo -e "${GREEN}Health endpoint is accessible.${NC}"
else
  echo -e "${RED}Health endpoint is not accessible. HTTP status code: $HEALTH_STATUS.${NC}"
fi

# Manually test the health probe endpoints
LB_IP=$(kubectl get svc -n $INGRESS_CONTROLLER_NAMESPACE -l app.kubernetes.io/name=$INGRESS_CONTROLLER_NAME -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")

# Retrieve the health probe ports dynamically
HTTP_HEALTH_PROBE_PORT=$(az network lb probe list --resource-group $MANAGED_RG --lb-name $LB_NAME --query "[?protocol=='Http'].port" -o tsv)
HTTPS_HEALTH_PROBE_PORT=$(az network lb probe list --resource-group $MANAGED_RG --lb-name $LB_NAME --query "[?protocol=='Https'].port" -o tsv)

echo -e "${YELLOW}Manually testing the health probe endpoints...${NC}"

# Test HTTP health probe
echo "curl -m $CURL_TIMEOUT -v http://$LB_IP:$HTTP_HEALTH_PROBE_PORT/"
curl -m $CURL_TIMEOUT -v http://$LB_IP:$HTTP_HEALTH_PROBE_PORT/

# Test HTTPS health probe
echo "curl -m $CURL_TIMEOUT -vk https://$LB_IP:$HTTPS_HEALTH_PROBE_PORT/"
curl -m $CURL_TIMEOUT -vk https://$LB_IP:$HTTPS_HEALTH_PROBE_PORT/

echo -e "${GREEN}All checks completed.${NC}"