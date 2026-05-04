***

```markdown
# 🚀 Enterprise Setup & Deployment Guide: AI-Powered Azure Log Analytics

> **Project Info:** This document outlines the standard operating procedures (SOP) for setting up, deploying, and maintaining the AI-powered Azure Log Analytics infrastructure and backend services.

---

## 📋 Prerequisites

Before initiating the setup, ensure the following enterprise tools and permissions are configured on your local workstation:

* **Azure Subscription:** Owner or Contributor RBAC role assignment
* **Azure CLI:** Latest stable version installed and authenticated
* **Terraform:** Version `>= 1.6.0`
* **Docker Desktop:** Required for local container development
* **Python:** Version `>= 3.11`
* **HuggingFace:** Active account and valid API key
* **Git:** Version control client

---

## 💻 Quick Start (Local Development)

### 1. Repository Initialization
Clone the enterprise repository to your local development environment.
```bash
git clone [https://github.com/LearningGallery/azure-log-analytics-ai.git](https://github.com/LearningGallery/azure-log-analytics-ai.git)
cd azure-log-analytics-ai
```

### 2. Infrastructure Provisioning
Define your target environment variables and execute the Azure setup script.

> **Note:** The location is set to `southeastasia` by default. Adjust this if your organizational policies require a different Azure region.
```bash
# Set environment variables
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export PROJECT_NAME="ailoganalytics"
export ENVIRONMENT="dev"
export LOCATION="southeastasia"

# Run setup script
chmod +x scripts/setup-azure.sh
./scripts/setup-azure.sh
```

### 3. Terraform Backend Configuration
Configure the state backend for Terraform. Update the `.tfvars` file with your specific organizational parameters.
```bash
# Update terraform/environments/dev/terraform.tfvars
cat > terraform/environments/dev/terraform.tfvars << EOF
project_name     = "ailoganalytics"
environment      = "dev"
location         = "southeastasia"
cost_center      = "IT-Development"
owner_email      = "your.email@company.com"

# Update with your ACR name from setup script
acr_name = "ailoganalyticsdevacr"

# Add your HuggingFace API key
# This will be set via environment variable in CI/CD
EOF
```

### 4. Execute Infrastructure Deployment
Initialize the backend and apply the infrastructure configuration.

```bash
cd terraform/environments/dev

# Initialize Terraform state storage
terraform init \
  -backend-config="storage_account_name=tfstateailoganalyticsdev" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev.tfstate"

# Generate execution plan
terraform plan

# Apply infrastructure changes
terraform apply
```

### 5. Application Environment Setup
Configure your local Python environment and initialize the backend API.
```bash
# Return to project root
cd ../../..

# Initialize environment variables
cp .env.example .env

# Retrieve workspace ID from Terraform output
terraform -chdir=terraform/environments/dev output -raw primary_workspace_customer_id

# Install Python dependencies via Poetry
poetry install

# Run the FastAPI application
poetry run uvicorn src.api.main:app --reload
```

### 6. API Verification
Access the local Swagger documentation to verify the deployment.

```text
http://localhost:8000/docs
```

---

## 🌍 Production Deployment

### 1. CI/CD Pipeline Secrets
Securely add the following variables to your GitHub Repository Secrets to enable automated deployments:

* `AZURE_SUBSCRIPTION_ID`
* `AZURE_CLIENT_ID`
* `AZURE_CLIENT_SECRET`
* `AZURE_TENANT_ID`
* `HUGGINGFACE_API_KEY`
* `ACR_LOGIN_SERVER`
* `ACR_USERNAME`
* `ACR_PASSWORD`
* `LOG_ANALYTICS_WORKSPACE_ID`
* `STORAGE_ACCOUNT_NAME`

### 2. Trigger Deployment Pipeline
Deployments are managed via GitHub Actions.

```bash
# Push to the main branch to trigger the production workflow
git push origin main
```
> **Tip:** You can also trigger the deployment manually using the GitHub Actions `workflow_dispatch` event in the repository UI.

### 3. Verify Container App Status
Retrieve the fully qualified domain name (FQDN) of your production instance.
```bash
# Get Container App URL
az containerapp show \
  --name ai-log-api \
  --resource-group ailoganalytics-prod-rg \
  --query properties.configuration.ingress.fqdn -o tsv
```

---

## ⚙️ System Configuration

### Environment Variables Matrix

| Variable | Description | Required |
| :--- | :--- | :--- |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | Yes |
| `AZURE_TENANT_ID` | Azure AD tenant ID | Yes |
| `AZURE_CLIENT_ID` | Service principal client ID | Yes |
| `AZURE_CLIENT_SECRET` | Service principal secret | Yes |
| `HUGGINGFACE_API_KEY` | HuggingFace API token | Yes |
| `LOG_ANALYTICS_WORKSPACE_ID` | Workspace customer ID | Yes |
| `ENVIRONMENT` | Environment name (`dev`/`staging`/`prod`) | Yes |
| `DEBUG` | Enable application debug mode | No |

### Terraform Variables Reference
For a complete list of infrastructure variables, consult `terraform/variables.tf`. Key configurable parameters include:

* **`log_retention_days`:** 30-730 (Default: 90)
* **`daily_quota_gb`:** Daily log ingestion limit
* **`enable_geo_redundancy`:** Toggle for Multi-region deployment
* **`enable_prometheus`:** Toggle for Azure Monitor Managed Prometheus

---

## 🧪 Quality Assurance & Testing

### Unit Testing
```bash
poetry run pytest tests/unit -v
```

### Integration Testing
> **Warning:** Integration tests require an active Azure connection.
```bash
export AZURE_SUBSCRIPTION_ID="your-id"
poetry run pytest tests/integration -v --azure
```

### Load & Performance Testing
```bash
# Install load testing dependencies
poetry add --group dev locust

# Execute distributed load test
poetry run locust -f tests/load/locustfile.py
```

---

## 🔧 Troubleshooting Guide

### Issue: Terraform Backend Synchronization Error
**Resolution:** Manually recreate the backend container if the state lock is permanently corrupted.
```bash
az storage container create \
  --name tfstate \
  --account-name tfstateailoganalyticsdev
```

### Issue: Container App Fails to Start
**Resolution:** Inspect the live container logs to identify startup failures.
```bash
az containerapp logs show \
  --name ai-log-api \
  --resource-group ailoganalytics-dev-rg \
  --follow
```

### Issue: KQL Query Timeout
**Resolutions:**
* Review query complexity and optimize joins.
* Reduce the target time range (`TimeGenerated`).
* Check the workspace for ingestion volume throttling.

### Issue: HuggingFace API Rate Limit Exceeded
**Resolutions:**
* Upgrade to a HuggingFace Pro account for higher thresholds.
* Implement Redis/Memcached request caching.
* Migrate to self-hosted models within your private infrastructure.

---

## 🛡️ Operations & Maintenance

### Machine Learning Model Updates
Trigger the automated workflow to retrain and deploy updated AI models.
```bash
gh workflow run ml-training.yml
```

### State & Configuration Backups
Regularly backup your infrastructure state and custom queries.
```bash
# Export Terraform state to local JSON
terraform state pull > backup-state.json

# Backup custom KQL saved searches
az monitor log-analytics workspace saved-search list \
  --workspace-name ailoganalytics-prod-law-primary \
  --resource-group ailoganalytics-prod-rg > backup-queries.json
```

### Cloud Cost Monitoring
Generate a quick usage report for your resource group to monitor burn rate.
```bash 
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --query "[?contains(instanceName, 'ailoganalytics')]"
```

---

## 📞 Enterprise Support

* **Technical Issues:** Submit via GitHub Issues tracker
* **Internal Documentation:** [LearningGallery.co](https://LearningGallery.co)
* **Lead Architect:** abutalha3005@gmail.com

---

## ✅ Project Implementation Status

### Infrastructure Configuration
- [x] Terraform modules for all Azure resources
- [x] AMPLS configuration for private connectivity
- [x] Multi-workspace support
- [x] Geo-redundancy option
- [x] Data Collection Rules (DCR)
- [x] VM Insights configuration
- [x] Container Insights (AKS)
- [x] Storage lifecycle policies
- [x] Key Vault integration

### Application Backend
- [x] FastAPI backend
- [x] Azure Monitor client
- [x] KQL query generator
- [x] Natural language to KQL
- [x] Root cause analysis
- [x] Anomaly detection
- [x] Pattern recognition
- [x] Incident prediction
- [x] Compliance reporting (GDPR, PDPA, MAS)

### AI & Machine Learning
- [x] LangChain integration
- [x] HuggingFace models
- [x] Sentence transformers
- [x] ML model training
- [x] Anomaly detection algorithms
- [x] Pattern clustering

### DevOps & CI/CD
- [x] Docker configuration
- [x] GitHub Actions CI/CD
- [x] Terraform automation
- [x] Container registry
- [x] Monitoring setup
- [x] Security scanning

### Quality Assurance
- [x] Unit tests
- [x] Integration tests
- [x] API tests
- [x] Load tests (Locust)

### Documentation
- [x] Architecture guide
- [x] API reference
- [x] Setup instructions
- [x] KQL query examples
- [x] Compliance guide
- [x] Troubleshooting guide

### Security & Compliance
- [x] RBAC configuration
- [x] Managed Identity
- [x] Private Link (AMPLS)
- [x] Secrets management
- [x] TLS/HTTPS
- [x] Audit logging

### Telemetry & Monitoring
- [x] Self-monitoring
- [x] Health checks
- [x] Prometheus metrics
- [x] Grafana dashboards
- [x] Alert rules
```
```

### 🎉 Congratulations! 
You now have a complete, enterprise-grade AI-powered Azure Log Analytics solution ready for deployment!

**Your Next Steps:**
1. Clone the repository
2. Run `scripts/setup-azure.sh`
3. Configure your `.env` file
4. Deploy with Terraform
5. Build and push your Docker image
6. Deploy to Azure Container Apps
7. Start analyzing logs with AI!

**Would you like me to create any additional components to complete your documentation such as:**
1. Grafana dashboard JSON definitions?
2. More KQL query templates?
3. Advanced ML models configuration?
4. Azure Policy definitions?
5. Cost optimization scripts?

***