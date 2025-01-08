# Setting Up Terraform for AKS Shared Production Cluster

## Prerequisites

1. **Install Terraform:**
   - Download Terraform from the [official website](https://www.terraform.io/downloads).
   - Verify installation:
     ```bash
     terraform --version
     ```

2. **Install Azure CLI:**
   - Install Azure CLI from [Microsoft Docs](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).
   - Log in to Azure:
     ```bash
     az login
     ```

3. **Configure Access to Azure:**
   - Ensure you have sufficient permissions to create resources in Azure.
   - Set the desired subscription:
     ```bash
     az account set --subscription "<subscription-id>"
     ```

## Setting Up Terraform Configuration

1. **Clone or Create the Terraform Project Directory:**
   - Create a directory to store your Terraform files:
     ```bash
     mkdir aks-terraform-setup
     cd aks-terraform-setup
     ```
   - Copy the provided Terraform configuration file (`main.tf`) into this directory.

2. **Initialize Terraform:**
   - Initialize Terraform to download necessary providers and set up the environment:
     ```bash
     terraform init
     ```

3. **Validate the Configuration:**
   - Ensure your configuration is error-free:
     ```bash
     terraform validate
     ```

4. **Plan the Deployment:**
   - Preview the changes Terraform will apply:
     ```bash
     terraform plan
     ```

5. **Deploy the Resources:**
   - Apply the configuration to create the AKS cluster and related resources:
     ```bash
     terraform apply
     ```
   - Confirm the action by typing `yes` when prompted.

## Accessing the AKS Cluster

1. **Fetch AKS Cluster Credentials:**
   - Configure `kubectl` to connect to your AKS cluster:
     ```bash
     az aks get-credentials --resource-group aks-shared-prod-rg --name aks-shared-prod-cluster
     ```

2. **Verify the Cluster:**
   - Ensure the cluster is accessible:
     ```bash
     kubectl get nodes
     ```

## Optional: Store Terraform State Remotely

1. **Create an Azure Storage Account:**
   ```bash
   az storage account create --name <storage-account-name> --resource-group aks-shared-prod-rg --location "East US" --sku Standard_LRS
   ```

2. **Create a Storage Container:**
   ```bash
   az storage container create --name terraform-state --account-name <storage-account-name>
   ```

3. **Update Terraform Backend Configuration:**
   - Add the following to your `main.tf` file:
     ```hcl
     terraform {
       backend "azurerm" {
         resource_group_name  = "aks-shared-prod-rg"
         storage_account_name = "<storage-account-name>"
         container_name       = "terraform-state"
         key                  = "terraform.tfstate"
       }
     }
     ```

4. **Reinitialize Terraform:**
   ```bash
   terraform init
   ```

## Clean Up Resources

To remove the deployed resources:
```bash
terraform destroy
```
