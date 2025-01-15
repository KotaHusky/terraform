#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to parse .tfvars file and extract variable values
parse_tfvars() {
  local tfvars_file=$1
  local var_name=$2
  grep -E "^${var_name}\s*=" "$tfvars_file" | sed -E "s/^${var_name}\s*=\s*\"(.*)\"/\1/"
}

# Path to your .tfvars file
TFVARS_FILE="terraform.tfvars"

# Extract variables from .tfvars file
SUBSCRIPTION_ID=$(parse_tfvars "$TFVARS_FILE" "subscription_id")
RESOURCE_GROUP=$(parse_tfvars "$TFVARS_FILE" "resource_group_name")
AKS_CLUSTER_NAME=$(parse_tfvars "$TFVARS_FILE" "aks_cluster_name")

# Log in to Azure
echo "Logging into Azure..."
az login

# Set the subscription
echo "Setting the subscription to $SUBSCRIPTION_ID..."
az account set --subscription $SUBSCRIPTION_ID

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
terraform apply -var-file=$TFVARS_FILE -auto-approve

echo "Terraform apply completed successfully."