#!/bin/bash

# Load variables from terraform.tfvars
TFVARS_FILE="./terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
  echo "terraform.tfvars file not found!"
  exit 1
fi

# Extract variables from terraform.tfvars
subscription_id=$(grep 'subscription_id' $TFVARS_FILE | awk -F ' = ' '{print $2}' | tr -d '"')
location=$(grep 'location' $TFVARS_FILE | awk -F ' = ' '{print $2}' | tr -d '"')
tenant_id=$(grep 'tenant_id' $TFVARS_FILE | awk -F ' = ' '{print $2}' | tr -d '"')
admin_user_object_id=$(grep 'admin_user_object_id' $TFVARS_FILE | awk -F ' = ' '{print $2}' | tr -d '"')
acr_name=$(grep 'acr_name' $TFVARS_FILE | awk -F ' = ' '{print $2}' | tr -d '"')
resource_group_name=$(grep 'resource_group_name' $TFVARS_FILE | awk -F ' = ' '{print $2}' | tr -d '"')

# Define the paths to the manifest files
AADPODIDENTITY_CRDS="modules/azure/agic/manifests/aadpodidentity-crds.yaml"
PROHIBITED_TARGET_CRD="modules/azure/agic/manifests/prohibited-target-crd.yaml"
PROHIBIT_ALL_EXCEPT_WEBAPP="modules/azure/agic/manifests/prohibit-all-except-webapp.yaml"

# Function to check if a CRD exists
check_crd() {
  local crd_name=$1
  kubectl get crd $crd_name &> /dev/null
  return $?
}

# Function to apply a manifest file
apply_manifest() {
  local manifest_file=$1
  echo "Applying $manifest_file..."
  kubectl apply -f $manifest_file
}

# Check if the -f argument is supplied
FORCE_REINSTALL=false
if [[ "$1" == "-f" ]]; then
  FORCE_REINSTALL=true
fi

# Update kubectl context using Azure CLI
echo "Updating kubectl context using Azure CLI..."
az aks get-credentials --resource-group $resource_group_name --name "aks-shared-prod-cluster" --overwrite-existing

# Check if we can connect to the Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
  echo "Unable to connect to the Kubernetes cluster. Please check your Kubernetes context."
  exit 1
fi

# Check and apply Azure AD Pod Identity CRDs
if $FORCE_REINSTALL || ! check_crd "azureidentities.aadpodidentity.k8s.io"; then
  apply_manifest $AADPODIDENTITY_CRDS
else
  echo "AzureIdentity CRD already exists."
fi

if $FORCE_REINSTALL || ! check_crd "azureidentitybindings.aadpodidentity.k8s.io"; then
  apply_manifest $AADPODIDENTITY_CRDS
else
  echo "AzureIdentityBinding CRD already exists."
fi

# Check and apply Azure Ingress Prohibited Target CRD
if $FORCE_REINSTALL || ! check_crd "azureingressprohibitedtargets.appgw.ingress.k8s.io"; then
  apply_manifest $PROHIBITED_TARGET_CRD
else
  echo "AzureIngressProhibitedTarget CRD already exists."
fi

# Apply the Prohibit All Except Webapp manifest
apply_manifest $PROHIBIT_ALL_EXCEPT_WEBAPP

# Wait for a few seconds to ensure the CRDs are registered
echo "Waiting for CRDs to be registered..."
sleep 30

# Check if the CRDs are applied
echo "Checking if CRDs are applied..."
kubectl get crds | grep -E 'azureidentities|azureidentitybindings|azureingressprohibitedtargets'

# Check the status of the CRDs
echo "Checking the status of AzureIdentity CRD..."
kubectl get crd azureidentities.aadpodidentity.k8s.io -o yaml

echo "Checking the status of AzureIdentityBinding CRD..."
kubectl get crd azureidentitybindings.aadpodidentity.k8s.io -o yaml

echo "Checking the status of AzureIngressProhibitedTarget CRD..."
kubectl get crd azureingressprohibitedtargets.appgw.ingress.k8s.io -o yaml

# Check if the resources are created
echo "Checking if AzureIdentity resources are created..."
kubectl get azureidentity

echo "Checking if AzureIdentityBinding resources are created..."
kubectl get azureidentitybinding

echo "Checking if AzureIngressProhibitedTarget resources are created..."
kubectl get azureingressprohibitedtarget