#!/bin/bash

# Azure Setup Script for AI Log Analytics
# This script sets up the required Azure resources

set -e

echo "🚀 Setting up Azure Infrastructure for AI Log Analytics"

# Variables
PROJECT_NAME="\${PROJECT_NAME:-ailoganalytics}"
ENVIRONMENT="\${ENVIRONMENT:-dev}"
LOCATION="\${LOCATION:-southeastasia}"
SUBSCRIPTION_ID="\${AZURE_SUBSCRIPTION_ID}"

# Derived variables
RESOURCE_GROUP="\${PROJECT_NAME}-\${ENVIRONMENT}-rg"
LOG_WORKSPACE="\${PROJECT_NAME}-\${ENVIRONMENT}-law"
STORAGE_ACCOUNT="\${PROJECT_NAME}\${ENVIRONMENT}sa"
ACR_NAME="\${PROJECT_NAME}\${ENVIRONMENT}acr"

# Colors for output
GREEN='\033[0.32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "\${GREEN}Configuration:\${NC}"
echo "  Project: \$PROJECT_NAME"
echo "  Environment: \$ENVIRONMENT"
echo "  Location: \$LOCATION"
echo "  Resource Group: \$RESOURCE_GROUP"
echo ""

# Login check
echo -e "\${YELLOW}Checking Azure login status...\${NC}"
az account show > /dev/null 2>&1 || {
    echo "Not logged in to Azure. Please login:"
    az login
}

# Set subscription
if [ -n "\$SUBSCRIPTION_ID" ]; then
    echo "Setting subscription to \$SUBSCRIPTION_ID"
    az account set --subscription "\$SUBSCRIPTION_ID"
fi

# Create resource group
echo -e "\${GREEN}Creating resource group...\${NC}"
az group create \
    --name "\$RESOURCE_GROUP" \
    --location "\$LOCATION" \
    --tags Environment="\$ENVIRONMENT" Project="\$PROJECT_NAME"

# Create storage account for Terraform state
echo -e "\${GREEN}Creating storage account for Terraform state...\${NC}"
TFSTATE_STORAGE="tfstate\${PROJECT_NAME}\${ENVIRONMENT}"
az storage account create \
    --name "\$TFSTATE_STORAGE" \
    --resource-group "\$RESOURCE_GROUP" \
    --location "\$LOCATION" \
    --sku Standard_LRS \
    --encryption-services blob

# Create container for Terraform state
az storage container create \
    --name "tfstate" \
    --account-name "\$TFSTATE_STORAGE"

# Get storage account key
STORAGE_KEY=\$(az storage account keys list \
    --resource-group "\$RESOURCE_GROUP" \
    --account-name "\$TFSTATE_STORAGE" \
    --query '.value' -o tsv)

echo -e "\${GREEN}Terraform backend configuration:\${NC}"
echo "  storage_account_name = \"\$TFSTATE_STORAGE\""
echo "  container_name       = \"tfstate\""
echo "  key                  = \"\${ENVIRONMENT}.tfstate\""

# Create Azure Container Registry
echo -e "\${GREEN}Creating Azure Container Registry...\${NC}"
az acr create \
    --name "\$ACR_NAME" \
    --resource-group "\$RESOURCE_GROUP" \
    --location "\$LOCATION" \
    --sku Basic

# Enable admin user (for development)
az acr update --name "\$ACR_NAME" --admin-enabled true

# Get ACR credentials
ACR_USERNAME=\$(az acr credential show --name "\$ACR_NAME" --query username -o tsv)
ACR_PASSWORD=\$(az acr credential show --name "\$ACR_NAME" --query passwords.value -o tsv)

echo -e "\${GREEN}✅ Setup complete!\${NC}"
echo ""
echo "Next steps:"
echo "1. Update terraform/environments/\${ENVIRONMENT}/terraform.tfvars"
echo "2. Run: cd terraform/environments/\${ENVIRONMENT} && terraform init"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"
echo ""
echo "Save these credentials securely:"
echo "ACR_NAME=\$ACR_NAME"
echo "ACR_USERNAME=\$ACR_USERNAME"
echo "ACR_PASSWORD=\$ACR_PASSWORD"
