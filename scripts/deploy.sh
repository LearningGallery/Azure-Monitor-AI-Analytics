#!/bin/bash

set -e

echo "🚀 Deploying AI Log Analytics to Azure..."

# Variables
RESOURCE_GROUP="ailoganalytics-prod-rg"
LOCATION="southeastasia"
ENVIRONMENT="prod"

# Login to Azure
echo "📝 Logging in to Azure..."
az login

# Set subscription
az account set --subscription "\${AZURE_SUBSCRIPTION_ID}"

# Initialize Terraform
echo "🔧 Initializing Terraform..."
cd terraform/environments/\${ENVIRONMENT}
terraform init

# Plan
echo "📋 Creating Terraform plan..."
terraform plan -out=tfplan

# Apply
echo "✅ Applying Terraform configuration..."
terraform apply tfplan

# Get outputs
echo "📤 Retrieving outputs..."
WORKSPACE_ID=\$(terraform output -raw primary_workspace_id)
CONTAINER_APP_FQDN=\$(terraform output -raw container_apps_fqdn)

echo "✨ Deployment complete!"
echo "Workspace ID: \${WORKSPACE_ID}"
echo "API URL: https://\${CONTAINER_APP_FQDN}"
