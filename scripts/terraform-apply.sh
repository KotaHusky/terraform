#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

AKS_CLUSTER_NAME="aks-shared-cluster"
RESOURCE_GROUP="aks-shared"

# Log in to Azure
echo "Logging into Azure..."
az login

# Get the AKS credentials
echo "Getting AKS credentials for cluster $AKS_CLUSTER_NAME in resource group $RESOURCE_GROUP..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate Terraform configuration
echo "Validating Terraform configuration..."
terraform validate

# Apply Terraform configuration using .tfvars file
echo "Applying Terraform configuration..."
terraform apply -auto-approve

echo "Terraform apply completed successfully."