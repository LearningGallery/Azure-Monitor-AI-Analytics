# API Reference

## Base URL
Production: https://your-app.azurecontainerapps.io Development: http://localhost:8000

## Authentication
```http
Authorization: Bearer <azure_ad_token>
```

## Endpoints

### Log Queries

#### Execute KQL Query
```bash 
POST /api/v1/logs/query
Content-Type: application/json

{
  "workspace_id": "12345678-1234-1234-1234-123456789012",
  "query": "Heartbeat | summarize count() by Computer",
  "timespan_hours": 24,
  "include_statistics": false
}
```
#### Response:
```bash 
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
#### Natural Language Query
```bash 
POST /api/v1/logs/query/natural
Content-Type: application/json

{
  "workspace_id": "12345678-1234-1234-1234-123456789012",
  "natural_query": "Show me failed logins in the last hour",
  "timespan_hours": 1
}
```
#### Response:
```bash 
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
### Analytics

#### Root Cause Analysis
```bash 
POST /api/v1/analytics/root-cause
Content-Type: application/json

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
#### Response:
```bash
{
  "status": "success",
  "analysis": "## Root Cause Analysis\n\n**Root Cause**: Database connection pool exhaustion...",
  "logs_analyzed": 2,
  "context": {...}
}
```
#### Anomaly Detection
```bash
POST /api/v1/analytics/anomaly-detection
Content-Type: application/json

{
  "workspace_id": "12345678-1234-1234-1234-123456789012",
  "metric_name": "% Processor Time",
  "timespan_hours": 24,
  "table_name": "Perf"
}
```
#### Response:
```bash
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

### Compliance

#### GDPR Compliance Check
```bash
GET /api/v1/compliance/gdpr?workspace_id=<id>&days=30
```

#### Response
```bash
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

#### Compliance Summary
```bash
GET /api/v1/compliance/summary?workspace_id=<id>&days=30
```

#### Response:
```bash
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
### Error Codes
```Table

| Code | Description                             |
| ---- | --------------------------------------- |
| 200  | Success                                 |
| 400  | Bad Request - Invalid parameters        |
| 401  | Unauthorized - Invalid/missing token    |
| 403  | Forbidden - Insufficient permissions    |
| 404  | Not Found - Resource doesn't exist      |
| 429  | Too Many Requests - Rate limit exceeded |
| 500  | Internal Server Error                   |
| 503  | Service Unavailable                     |
```
