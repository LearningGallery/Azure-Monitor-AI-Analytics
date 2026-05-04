#!/bin/bash

# Deploy API to Azure Container Apps

set -e

PROJECT_NAME="\${PROJECT_NAME:-ailoganalytics}"
ENVIRONMENT="\${ENVIRONMENT:-dev}"
LOCATION="\${LOCATION:-southeastasia}"
RESOURCE_GROUP="\${PROJECT_NAME}-\${ENVIRONMENT}-rg"
ACR_NAME="\${PROJECT_NAME}\${ENVIRONMENT}acr"
CONTAINER_APP_ENV="\${PROJECT_NAME}-\${ENVIRONMENT}-containerenv"
CONTAINER_APP_NAME="ai-log-api"

echo "🐳 Building and deploying Docker image..."

# Build image
docker build -t "\${ACR_NAME}.azurecr.io/\${CONTAINER_APP_NAME}:latest" \
    -f docker/services/api.Dockerfile .

# Login to ACR
az acr login --name "\$ACR_NAME"

# Push
# Push image
docker push "\${ACR_NAME}.azurecr.io/\${CONTAINER_APP_NAME}:latest"

echo "✅ Image pushed to ACR"

# Get ACR credentials
ACR_SERVER=\$(az acr show --name "\$ACR_NAME" --query loginServer -o tsv)
ACR_USERNAME=\$(az acr credential show --name "\$ACR_NAME" --query username -o tsv)
ACR_PASSWORD=\$(az acr credential show --name "\$ACR_NAME" --query passwords.value -o tsv)

# Deploy to Container Apps
echo "🚀 Deploying to Azure Container Apps..."

# Get Log Analytics workspace ID
WORKSPACE_ID=\$(az monitor log-analytics workspace show \
    --resource-group "\$RESOURCE_GROUP" \
    --workspace-name "\${PROJECT_NAME}-\${ENVIRONMENT}-law-primary" \
    --query customerId -o tsv)

WORKSPACE_KEY=\$(az monitor log-analytics workspace get-shared-keys \
    --resource-group "\$RESOURCE_GROUP" \
    --workspace-name "\${PROJECT_NAME}-\${ENVIRONMENT}-law-primary" \
    --query primarySharedKey -o tsv)

# Create or update container app
az containerapp create \
    --name "\$CONTAINER_APP_NAME" \
    --resource-group "\$RESOURCE_GROUP" \
    --environment "\$CONTAINER_APP_ENV" \
    --image "\${ACR_SERVER}/\${CONTAINER_APP_NAME}:latest" \
    --registry-server "\$ACR_SERVER" \
    --registry-username "\$ACR_USERNAME" \
    --registry-password "\$ACR_PASSWORD" \
    --target-port 8000 \
    --ingress 'external' \
    --min-replicas 1 \
    --max-replicas 5 \
    --cpu 1.0 \
    --memory 2.0Gi \
    --secrets \
        law-workspace-id="\$WORKSPACE_ID" \
        law-workspace-key="\$WORKSPACE_KEY" \
        hf-api-key="\$HUGGINGFACE_API_KEY" \
    --env-vars \
        AZURE_LOG_ANALYTICS_WORKSPACE_ID=secretref:law-workspace-id \
        AZURE_LOG_ANALYTICS_KEY=secretref:law-workspace-key \
        HUGGINGFACE_API_KEY=secretref:hf-api-key \
        ENVIRONMENT="\$ENVIRONMENT"

# Get FQDN
FQDN=\$(az containerapp show \
    --name "\$CONTAINER_APP_NAME" \
    --resource-group "\$RESOURCE_GROUP" \
    --query properties.configuration.ingress.fqdn -o tsv)

echo "✅ Deployment complete!"
echo ""
echo "API URL: https://\$FQDN"
echo "Health: https://\$FQDN/health"
echo "Docs: https://\$FQDN/docs"
