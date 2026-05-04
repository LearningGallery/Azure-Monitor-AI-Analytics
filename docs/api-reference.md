# 🔌 API Reference Guide: AI-Powered Azure Log Analytics

> **Developer Info:** This document serves as the official API contract for interacting with the AI-Powered Azure Log Analytics backend. It details environments, authentication requirements, core endpoints, and system behaviors.

---

## 🌍 Environments & Authentication

### Base URLs
Direct your API requests to the appropriate environment endpoint:

* **Production:** `https://your-app.azurecontainerapps.io`
* **Development:** `http://localhost:8000`

### Authentication
All API endpoints (except health checks) require a valid Azure AD bearer token. Pass this token in the `Authorization` header of your HTTP request.
```http
Authorization: Bearer <azure_ad_token>
```

---

## 📊 Core Endpoints: Log Queries

### 1. Execute KQL Query
Executes a raw Kusto Query Language (KQL) string directly against the specified Log Analytics workspace.

**Endpoint:** `POST /api/v1/logs/query`  
**Content-Type:** `application/json`

#### Request Payload
```json
{
  "workspace_id": "12345678-1234-1234-1234-123456789012",
  "query": "Heartbeat | summarize count() by Computer",
  "timespan_hours": 24,
  "include_statistics": false
}
```

#### Response
```json
{
  "status": "success",
  "row_count": 10,
  "results": [
    {
      "Computer": "server1",
      "count_": 144
    }
  ],
  "statistics": null
}
```

### 2. Natural Language Query
Leverages the LangChain AI engine to translate natural language into an executable KQL query, runs it, and returns the results.

**Endpoint:** `POST /api/v1/logs/query/natural`  
**Content-Type:** `application/json`

#### Request Payload
```json
{
  "workspace_id": "12345678-1234-1234-1234-123456789012",
  "natural_query": "Show me failed logins in the last hour",
  "timespan_hours": 1
}
```

#### Response
```json
{
  "natural_query": "Show me failed logins in the last hour",
  "generated_kql": "SecurityEvent\n| where TimeGenerated > ago(1h)\n| where EventID == 4625...",
  "is_valid": true,
  "warnings": [],
  "results": {
    "status": "success",
    "row_count": 5,
    "results": [...]
  }
}
```

---

## 🧠 Core Endpoints: AI Analytics

### 1. Root Cause Analysis
Analyzes an array of error logs and system context to determine the most likely root cause of a system failure.

**Endpoint:** `POST /api/v1/analytics/root-cause`  
**Content-Type:** `application/json`

#### Request Payload
```json
{
  "workspace_id": "12345678-1234-1234-1234-123456789012",
  "error_logs": [
    "Database connection timeout",
    "Failed to connect to SQL server"
  ],
  "context": {
    "service": "payment-api",
    "environment": "production",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

#### Response
```json
{
  "status": "success",
  "analysis": "## Root Cause Analysis\n\n**Root Cause**: Database connection pool exhaustion...",
  "logs_analyzed": 2,
  "context": {
    "service": "payment-api",
    "environment": "production",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### 2. Anomaly Detection
Applies statistical and machine learning models to detect anomalies within a specified metric over time.

**Endpoint:** `POST /api/v1/analytics/anomaly-detection`  
**Content-Type:** `application/json`

#### Request Payload
```json
{
  "workspace_id": "12345678-1234-1234-1234-123456789012",
  "metric_name": "% Processor Time",
  "timespan_hours": 24,
  "table_name": "Perf"
}
```

#### Response
```json
{
  "status": "success",
  "metric": "% Processor Time",
  "anomalies_count": 3,
  "anomalies": [
    {
      "timestamp": "2024-01-15T14:30:00Z",
      "value": 95.5,
      "z_score": 3.2,
      "deviation_percent": 45.2,
      "computer": "server1"
    }
  ],
  "statistics": {
    "mean": 65.8,
    "std": 12.3,
    "min": 45.0,
    "max": 95.5,
    "data_points": 1440
  },
  "explanation": "The CPU usage spike indicates..."
}
```

---

## 🛡️ Core Endpoints: Compliance

### 1. GDPR Compliance Check
Generates a specific compliance report evaluating data retention and GDPR-related policies for a given workspace.

**Endpoint:** `GET /api/v1/compliance/gdpr`

#### Query Parameters
* `workspace_id` (string, required)
* `days` (integer, optional)

#### Response
```json
{
  "report_type": "GDPR",
  "time_range": "Last 30 days",
  "findings": [
    {
      "severity": "HIGH",
      "category": "Data Retention",
      "finding": "Data retained for 400 days (GDPR recommends ≤365)",
      "recommendation": "Review retention policies"
    }
  ],
  "compliance_score": 85.0,
  "generated_at": "2024-01-15T10:00:00Z"
}
```

### 2. Compliance Summary
Retrieves a holistic compliance score spanning multiple regulatory frameworks (GDPR, PDPA, MAS TRM).

**Endpoint:** `GET /api/v1/compliance/summary`

#### Query Parameters
* `workspace_id` (string, required)
* `days` (integer, optional)

#### Response
```json
{
  "workspace_id": "12345678-1234-1234-1234-123456789012",
  "report_period": "Last 30 days",
  "generated_at": "2024-01-15T10:00:00Z",
  "compliance_frameworks": {
    "GDPR": {
      "score": 85.0,
      "findings_count": 4,
      "critical_findings": 1
    },
    "PDPA": {
      "score": 90.0,
      "findings_count": 3,
      "critical_findings": 0
    },
    "MAS_TRM": {
      "score": 88.0,
      "findings_count": 5,
      "critical_findings": 1
    }
  },
  "overall_score": 87.67,
  "recommendations": [...]
}
```

---

## ⚙️ System Specifications

### Error Codes
Standard HTTP status codes are returned to indicate the success or failure of an API request.

| Code | Status | Description |
| :--- | :--- | :--- |
| **200** | `OK` | Success |
| **400** | `Bad Request` | Invalid parameters or malformed payload |
| **401** | `Unauthorized` | Invalid, expired, or missing Bearer token |
| **403** | `Forbidden` | Valid token, but insufficient permissions |
| **404** | `Not Found` | Requested resource/workspace doesn't exist |
| **429** | `Too Many Requests` | Rate limit exceeded |
| **500** | `Internal Server Error` | Backend system or integration failure |
| **503** | `Service Unavailable` | Azure Monitor or LangChain temporarily unavailable |

### Rate Limits
API quotas are enforced per tenant based on your subscription tier:
* **Free Tier:** 100 requests / hour
* **Standard Tier:** 1,000 requests / hour
* **Enterprise Tier:** Unlimited

### Pagination
For endpoints returning large datasets, append standard pagination parameters to your GET request:
```http
GET /api/v1/logs/query?workspace_id=<id>&limit=100&offset=0
```

### Webhooks (🚀 Coming Soon)
Register webhooks to receive real-time, push-based alerts for AI insights and system anomalies.

**Endpoint:** `POST /api/v1/webhooks`  
**Content-Type:** `application/json`

#### Request Payload
```json
{
  "url": "[https://your-service.com/webhook](https://your-service.com/webhook)",
  "events": ["anomaly_detected", "incident_predicted"],
  "secret": "your_webhook_secret"
}
