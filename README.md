# Terraform AKS Setup <!-- omit in toc -->

![Terraform](https://img.shields.io/badge/Terraform-0.14.5-blueviolet)
![Azure](https://img.shields.io/badge/Azure-Cloud-blue)
![AKS](https://img.shields.io/badge/AKS-Kubernetes-blue)
![Helm](https://img.shields.io/badge/Helm-Kubernetes-blue)
![License](https://img.shields.io/badge/License-MIT-green)

This repository contains Terraform configurations for setting up an Azure Kubernetes Service (AKS) cluster with supporting infrastructure. It includes modules for Azure AD, AKS, ACR, and networking. The setup also integrates automated certificate management with cert-manager and Let's Encrypt. Helm is used for deploying applications and managing Kubernetes resources.

## Table of Contents <!-- omit in toc -->

- [About](#about)
  - [Who is this for?](#who-is-this-for)
  - [Estimated Cost](#estimated-cost)
  - [Why use Terraform?](#why-use-terraform)
  - [Why use AKS?](#why-use-aks)
  - [Why use Helm?](#why-use-helm)
- [Prerequisites](#prerequisites)
- [Setting Up Terraform Configuration](#setting-up-terraform-configuration)
  - [Clone the Repository](#clone-the-repository)
  - [Create a `terraform.tfvars` File](#create-a-terraformtfvars-file)
  - [Getting `terraform.tfvars` Information](#getting-terraformtfvars-information)
- [Using Terraform](#using-terraform)
  - [Initialize Terraform](#initialize-terraform)
  - [Validate the Configuration](#validate-the-configuration)
  - [Plan the Deployment](#plan-the-deployment)
  - [Deploy the Resources](#deploy-the-resources)
- [Accessing the AKS Cluster](#accessing-the-aks-cluster)
  - [Fetch AKS Cluster Credentials](#fetch-aks-cluster-credentials)
  - [Verify the Cluster](#verify-the-cluster)
- [Optional: Store Terraform State Remotely](#optional-store-terraform-state-remotely)
  - [Create an Azure Storage Account](#create-an-azure-storage-account)
  - [Create a Storage Container](#create-a-storage-container)
  - [Configure Backend in `main.tf`](#configure-backend-in-maintf)
- [Cleaning Up](#cleaning-up)
- [Additional Resources](#additional-resources)

## About

### Who is this for?

This repository is for DevOps engineers, cloud architects, and developers who want to set up a scalable and secure AKS cluster using Terraform. It is designed for those who prefer Infrastructure as Code (IaC) for managing cloud resources. This setup is suitable home labs, enterprise environments, and development teams looking to leverage AKS for containerized applications.

### Estimated Cost

Approximately **$50 per month**. Actual costs may vary based on usage and Azure pricing.

Use Reserved Instances for cost savings.

### Why use Terraform?

Terraform is used for its declarative approach to infrastructure as code, enabling consistent and repeatable deployments. It allows for version control, collaboration, and easy management of infrastructure changes.

### Why use AKS?

AKS is a managed Kubernetes service that simplifies the deployment, management, and scaling of containerized applications. It provides built-in monitoring, security, and integration with Azure services. Cloud-native applications can benefit from AKS's scalability and flexibility.

### Why use Helm?

Helm is a package manager for Kubernetes that simplifies the deployment and management of applications on AKS. It allows for easy installation, upgrading, and rollback of applications using pre-configured charts. Helm streamlines the deployment process and enhances the overall management of Kubernetes resources.

## Prerequisites

**Install Terraform:**
Download Terraform from the [official website](https://www.terraform.io/downloads). Verify installation:

```bash
terraform --version
```

**Install Azure CLI:**
Install Azure CLI from [Microsoft Docs](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli). Log in to Azure:

```bash
az login
```

**Configure Access to Azure:**
Ensure you have sufficient permissions to create resources in Azure. Set the desired subscription:

```bash
az account set --subscription "<subscription-id>"
```

## Setting Up Terraform Configuration

### Clone the Repository

**Clone the Repository:**
Clone this repository to your local machine:

```bash
git clone https://github.com/yourusername/terraform-aks-setup.git
cd terraform-aks-setup
```

### Create a `terraform.tfvars` File

Create a `terraform.tfvars` file in the root of the repository to define the necessary variables:

```hcl
subscription_id       = ""
location              = ""
tenant_id             = ""
admin_user_object_id  = ""
acr_name              = ""
resource_name_prefix  = ""
email                 = ""
domain                = ""
cloudflare_api_token  = ""
cloudflare_zone_id    = ""
```

### Getting `terraform.tfvars` Information

To fill in the `terraform.tfvars` file, you will need the following information:

- `subscription_id`: Your Azure subscription ID.
- `location`: The Azure region where you want to deploy the resources (e.g., "East US").
- `tenant_id`: Your Azure Active Directory tenant ID.
- `admin_user_object_id`: The object ID of the Azure AD user or group that will have admin access to the AKS cluster.
- `acr_name`: The name of the Azure Container Registry (ACR) to be created or used.
- `resource_name_prefix`: A prefix for naming the resources to avoid name conflicts.
- `email`: Your email address for notifications.
- `domain`: The domain name for your cluster.
- `cloudflare_api_token`: The API token for your Cloudflare account.
- `cloudflare_zone_id`: The Zone ID for your Cloudflare domain.

You can find most of this information in the Azure portal or by using the Azure CLI.

## Using Terraform

### Initialize Terraform

Download necessary providers and set up the environment:

```bash
terraform init
```

### Validate the Configuration

Ensure your configuration is error-free:

```bash
terraform validate
```

### Plan the Deployment

Preview the changes Terraform will apply:

```bash
terraform plan
```

### Deploy the Resources

Apply the configuration to create the AKS cluster and related resources:

```bash
terraform apply
```

Confirm the action by typing `yes` when prompted. Go get a coffee, this will take a while. ☕️

## Accessing the AKS Cluster

### Fetch AKS Cluster Credentials

Configure `kubectl` to connect to your AKS cluster:

```bash
az aks get-credentials --resource-group <resource-group-name> --name <aks-cluster-name>
```

### Verify the Cluster

Ensure the cluster is accessible:

```bash
kubectl get nodes
```

## Optional: Store Terraform State Remotely

### Create an Azure Storage Account

```bash
az storage account create --name <storage-account-name> --resource-group <resource-group-name> --location "East US" --sku Standard_LRS
```

### Create a Storage Container

```bash
az storage container create --name tfstate --account-name <storage-account-name>
```

### Configure Backend in `main.tf`

Update your `main.tf` file to include the backend configuration:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name   = "<resource-group-name>"
    storage_account_name  = "<storage-account-name>"
    container_name        = "tfstate"
    key                   = "terraform.tfstate"
  }
}
```

## Cleaning Up

To clean up the resources created by Terraform, run:

```bash
terraform destroy
```

Confirm the action by typing `yes` when prompted.

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs/index.html)
- [Azure Provider for Terraform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Helm Documentation](https://helm.sh/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Cloudflare API Documentation](https://api.cloudflare.com/)
- [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/)
