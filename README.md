# 🤖 AI-Powered Azure Log Analytics

Enterprise-grade AI-powered log analytics solution for Azure infrastructure, focusing on Azure Monitor, Log Analytics Workspaces, and AMPLS.

## 🎯 Features

### Core Capabilities
- ✅ **Multi-Workspace Aggregation**: Query across multiple Log Analytics workspaces
- ✅ **AMPLS Integration**: Private network connectivity with Azure Monitor Private Link Scope
- ✅ **OS-Level Monitoring**: Windows Event Logs, Syslog, Performance Counters
- ✅ **Container Insights**: AKS pod logs, metrics, and health monitoring
- ✅ **Azure Service Logs**: Activity Logs, Diagnostic Settings, Resource Logs

### AI/ML Features
- 🤖 **Natural Language to KQL**: Convert plain English to KQL queries
- 🔍 **Root Cause Analysis**: AI-powered incident investigation
- 📊 **Anomaly Detection**: ML-based anomaly detection in metrics
- 🎯 **Pattern Recognition**: Identify recurring log patterns
- ⚠️ **Incident Prediction**: Predictive analytics for potential outages

### Enterprise Features
- 🔐 **Private Link Support**: Full AMPLS integration
- 📈 **Cost Optimization**: Log ingestion cost analysis
- ✅ **Compliance**: GDPR, PDPA, MAS compliance helpers
- 🔄 **Multi-Region**: Geo-redundant workspace support

## 🏗️ Architecture
┌──────────────────────────────────────────────────────┐ │ Azure Monitor Ecosystem │ │ ┌─────────────┐ ┌──────────────┐ ┌─────────────┐ │ │ │ Log Analytics│ │ Container │ │ Sentinel │ │ │ │ Workspaces │ │ Insights │ │ (Optional) │ │ │ └──────┬───────┘ └──────┬───────┘ └──────┬──────┘ │ │ │ │ │ │ │ └──────────────────┴──────────────────┘ │ │ │ │ │ ┌────────▼────────┐ │ │ │ AMPLS │ │ │ │ (Private Link) │ │ │ └────────┬────────┘ │ └────────────────────────────┼──────────────────────────┘ │ ┌────────▼────────┐ │ FastAPI + │ │ LangChain │ └──────────────────┘


## 🚀 Quick Start

### Prerequisites
- Azure Subscription
- Terraform >= 1.6
- Python >= 3.11
- Docker (optional)
- HuggingFace API Key

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/azure-log-analytics-ai.git
cd azure-log-analytics-ai
bash
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your credentials
```

### 3. Deploy Infrastructure
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 4. Run API Locally
```bash
poetry install
poetry run uvicorn src.api.main:app --reload
```

### 5. Access API
```bash
http://localhost:8000/docs
```
## 📖 API Examples

### Natural Language Query
```bash
curl -X POST http://localhost:8000/api/v1/logs/query/natural \
  -H "Content-Type: application/json" \
  -d '{
    "workspace_id": "your-workspace-id",
    "natural_query": "Show me failed logins in the last hour"
  }'
```

### Root Cause Analysis
```bash
curl -X POST http://localhost:8000/api/v1/analytics/root-cause \
  -H "Content-Type: application/json" \
  -d '{
    "workspace_id": "your-workspace-id",
    "error_logs": ["Error connecting to database", "Timeout after 30s"],
    "context": {"service": "payment-api", "environment": "production"}
  }'
```

## 💰 Cost Estimate

### Development
    - Log Analytics: ~$5/month (5GB/day)
    - Container Apps: FREE tier
    - Storage: ~$2/month
    - Total: ~$7/month

### Production
    - Log Analytics: ~$50/month (100GB/day with commitment)
    - Container Apps: ~$20/month
    - Storage: ~$10/month
    - Azure: ~$150/month (3 nodes)
    - Total: ~$230/month