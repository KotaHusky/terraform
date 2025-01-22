#!/bin/bash

# Variables
RESOURCE_GROUP="aks-shared"
APP_GATEWAY_NAME="aks-shared-app-gateway"
NAMESPACE="webapps"
INGRESS_NAME="homepage-ingress"
SERVICE_NAME="homepage"
AGIC_NAMESPACE="agic"
AKS_CLUSTER="aks-shared-prod-cluster"

# Update kubectl context using Azure CLI
echo "Updating kubectl context using Azure CLI..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --overwrite-existing

# Check if we can connect to the Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
  echo "Unable to connect to the Kubernetes cluster. Please check your Kubernetes context."
  exit 1
fi

# Check if AGIC namespace exists
echo "Checking if AGIC namespace exists..."
if ! kubectl get namespace $AGIC_NAMESPACE &> /dev/null; then
  echo "Namespace $AGIC_NAMESPACE does not exist. Please ensure AGIC is deployed correctly."
  exit 1
fi

# Check if AGIC deployment exists
echo "Checking if AGIC deployment exists..."
if ! kubectl get deployment -n $AGIC_NAMESPACE &> /dev/null; then
  echo "No AGIC deployment found in namespace $AGIC_NAMESPACE. Please ensure AGIC is deployed correctly."
  exit 1
fi

# Check the Backend Pool Configuration
echo "Checking the Backend Pool Configuration..."
az network application-gateway address-pool show --resource-group $RESOURCE_GROUP --gateway-name $APP_GATEWAY_NAME --name dynamicPool

# Check the Health Probes
echo "Checking the Health Probes..."
az network application-gateway probe list --resource-group $RESOURCE_GROUP --gateway-name $APP_GATEWAY_NAME

# Check the Backend HTTP Settings
echo "Checking the Backend HTTP Settings..."
az network application-gateway http-settings list --resource-group $RESOURCE_GROUP --gateway-name $APP_GATEWAY_NAME

# Check the Backend Service
echo "Checking the Backend Service..."
kubectl get pods -n $NAMESPACE
kubectl describe service $SERVICE_NAME -n $NAMESPACE
kubectl describe pod -l app=$SERVICE_NAME -n $NAMESPACE
kubectl logs -l app=$SERVICE_NAME -n $NAMESPACE

# Check the Ingress Controller Logs
echo "Checking the Ingress Controller Logs..."
kubectl logs -l app=agic-ingress-azure -n $AGIC_NAMESPACE

# Verify the Ingress Resource
echo "Verifying the Ingress Resource..."
kubectl get ingress -n $NAMESPACE
kubectl describe ingress $INGRESS_NAME -n $NAMESPACE

echo "Diagnosis script finished."