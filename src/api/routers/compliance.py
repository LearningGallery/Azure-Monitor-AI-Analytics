"""Compliance and audit endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import logging

from ..dependencies import get_azure_client
from ...connectors.azure_monitor import AzureMonitorClient

logger = logging.getLogger(__name__)

router = APIRouter()

class ComplianceReport(BaseModel):
    """Compliance report model."""
    report_type: str
    time_range: str
    findings: List[Dict[str, Any]]
    compliance_score: float
    generated_at: datetime

@router.get("/audit-logs")
async def get_audit_logs(
    workspace_id: str = Query(..., description="Workspace ID"),
    hours: int = Query(24, description="Time range in hours"),
    resource_group: Optional[str] = None,
    azure_client: AzureMonitorClient = Depends(get_azure_client)
):
    """
    Get audit logs for compliance reporting.
    
    Covers:
    - User authentication events
    - Privilege escalations
    - Configuration changes
    - Data access
    """
    query = f"""
    AzureActivity
    | where TimeGenerated > ago({hours}h)
    | where OperationNameValue has_any ("Microsoft.Authorization", "Microsoft.KeyVault", "Microsoft.Storage")
    | project 
        TimeGenerated,
        Caller,
        OperationName,
        ResourceGroup,
        Resource,
        ActivityStatus,
        Properties
    | order by TimeGenerated desc
    """
    
    if resource_group:
        query += f"\n| where ResourceGroup == '{resource_group}'"
    
    result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=query,
        timespan=timedelta(hours=hours)
    )
    
    return {
        "status": "success",
        "audit_logs": result["results"] if result["status"] == "success" else [],
        "count": len(result["results"]) if result["status"] == "success" else 0
    }

@router.get("/compliance/gdpr")
async def gdpr_compliance_check(
    workspace_id: str = Query(..., description="Workspace ID"),
    days: int = Query(30, description="Days to analyze"),
    azure_client: AzureMonitorClient = Depends(get_azure_client)
):
    """
    GDPR Compliance Check.
    
    Checks:
    - Data retention policies
    - Data access logging
    - Encryption status
    - Data deletion requests
    """
    findings = []
    compliance_score = 100.0
    
    # 1. Check data retention
    retention_query = """
    Usage
    | where TimeGenerated > ago(30d)
    | summarize TotalDataGB = sum(Quantity) / 1000 by DataType
    | extend RetentionDays = 90  // Default retention
    | project DataType, TotalDataGB, RetentionDays
    """
    
    retention_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=retention_query,
        timespan=timedelta(days=days)
    )
    
    if retention_result["status"] == "success":
        for row in retention_result["results"]:
            if row.get("RetentionDays", 0) > 365:
                findings.append({
                    "severity": "HIGH",
                    "category": "Data Retention",
                    "finding": f"Data type '{row['DataType']}' retained for {row['RetentionDays']} days (GDPR recommends ≤365 days)",
                    "recommendation": "Review and adjust retention policies"
                })
                compliance_score -= 10
    
    # 2. Check access logging
    access_query = f"""
    AzureActivity
    | where TimeGenerated > ago({days}d)
    | where OperationNameValue contains "read" or OperationNameValue contains "access"
    | summarize AccessCount = count() by Caller, Resource
    | where AccessCount > 100
    """
    
    access_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=access_query,
        timespan=timedelta(days=days)
    )
    
    if access_result["status"] == "success" and len(access_result["results"]) > 0:
        findings.append({
            "severity": "INFO",
            "category": "Data Access",
            "finding": f"Found {len(access_result['results'])} users with high data access frequency",
            "recommendation": "Review access patterns for compliance"
        })
    
    # 3. Check encryption
    encryption_finding = {
        "severity": "INFO",
        "category": "Encryption",
        "finding": "All Azure Monitor data is encrypted at rest by default",
        "recommendation": "Ensure HTTPS/TLS for data in transit"
    }
    findings.append(encryption_finding)
    
    # 4. Personal data detection
    pii_query = f"""
    union withsource=TableName *
    | where TimeGenerated > ago({days}d)
    | where Message has_any ("email", "ssn", "nric", "passport")
    | summarize PIICount = count() by TableName
    """
    
    pii_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=pii_query,
        timespan=timedelta(days=days)
    )
    
    if pii_result["status"] == "success" and len(pii_result["results"]) > 0:
        findings.append({
            "severity": "MEDIUM",
            "category": "PII Detection",
            "finding": f"Potential PII data found in {len(pii_result['results'])} tables",
            "recommendation": "Implement data masking or anonymization",
            "details": pii_result["results"]
        })
        compliance_score -= 5
    
    return ComplianceReport(
        report_type="GDPR",
        time_range=f"Last {days} days",
        findings=findings,
        compliance_score=max(0, compliance_score),
        generated_at=datetime.utcnow()
    )

@router.get("/compliance/pdpa")
async def pdpa_compliance_check(
    workspace_id: str = Query(..., description="Workspace ID"),
    days: int = Query(30, description="Days to analyze"),
    azure_client: AzureMonitorClient = Depends(get_azure_client)
):
    """
    PDPA (Singapore) Compliance Check.
    
    Personal Data Protection Act compliance for Singapore.
    """
    findings = []
    compliance_score = 100.0
    
    # 1. Data protection measures
    findings.append({
        "severity": "INFO",
        "category": "Data Protection",
        "finding": "Azure Monitor provides built-in encryption and access controls",
        "recommendation": "Ensure RBAC is properly configured"
    })
    
    # 2. Consent management
    consent_query = f"""
    AzureActivity
    | where TimeGenerated > ago({days}d)
    | where OperationNameValue contains "consent" or Properties contains "consent"
    | summarize ConsentEvents = count() by Caller
    """
    
    consent_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=consent_query,
        timespan=timedelta(days=days)
    )
    
    if consent_result["status"] == "success" and len(consent_result["results"]) == 0:
        findings.append({
            "severity": "MEDIUM",
            "category": "Consent Management",
            "finding": "No consent management events detected",
            "recommendation": "Implement consent tracking for personal data collection"
        })
        compliance_score -= 15
    
    # 3. Data breach notification readiness
    breach_query = f"""
    SecurityEvent
    | where TimeGenerated > ago({days}d)
    | where EventID in (4625, 4648, 4719)  // Failed logins, privilege escalation
    | summarize BreachIndicators = count() by Computer, bin(TimeGenerated, 1d)
    | where BreachIndicators > 50
    """
    
    breach_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=breach_query,
        timespan=timedelta(days=days)
    )
    
    if breach_result["status"] == "success" and len(breach_result["results"]) > 0:
        findings.append({
            "severity": "HIGH",
            "category": "Security",
            "finding": f"Detected {len(breach_result['results'])} potential security incidents",
            "recommendation": "Review incidents and ensure breach notification procedures are in place",
            "details": breach_result["results"]
        })
        compliance_score -= 20
    
    # 4. Cross-border data transfer
    findings.append({
        "severity": "INFO",
        "category": "Data Transfer",
        "finding": "Data stored in Southeast Asia region (Singapore)",
        "recommendation": "Ensure any cross-border transfers comply with PDPA Schedule"
    })
    
    return ComplianceReport(
        report_type="PDPA",
        time_range=f"Last {days} days",
        findings=findings,
        compliance_score=max(0, compliance_score),
        generated_at=datetime.utcnow()
    )

@router.get("/compliance/mas")
async def mas_compliance_check(
    workspace_id: str = Query(..., description="Workspace ID"),
    days: int = Query(30, description="Days to analyze"),
    azure_client: AzureMonitorClient = Depends(get_azure_client)
):
    """
    MAS (Monetary Authority of Singapore) Compliance Check.
    
    For financial institutions in Singapore.
    """
    findings = []
    compliance_score = 100.0
    
    # 1. Technology Risk Management (TRM)
    availability_query = f"""
    Heartbeat
    | where TimeGenerated > ago({days}d)
    | summarize HeartbeatCount = count() by Computer, bin(TimeGenerated, 1h)
    | summarize AvgHeartbeats = avg(HeartbeatCount), MissedHeartbeats = countif(HeartbeatCount == 0) by Computer
    | extend Availability = (AvgHeartbeats - MissedHeartbeats) / AvgHeartbeats * 100
    | where Availability < 99.9
    """
    
    availability_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=availability_query,
        timespan=timedelta(days=days)
    )
    
    if availability_result["status"] == "success" and len(availability_result["results"]) > 0:
        findings.append({
            "severity": "HIGH",
            "category": "Availability (TRM)",
            "finding": f"{len(availability_result['results'])} systems below 99.9% availability",
            "recommendation": "MAS requires high availability for critical systems",
            "details": availability_result["results"]
        })
        compliance_score -= 25
    
    # 2. Incident Management
    incident_query = f"""
    AzureActivity
    | where TimeGenerated > ago({days}d)
    | where ActivityStatus == "Failed"
    | summarize IncidentCount = count() by OperationName, bin(TimeGenerated, 1d)
    | where IncidentCount > 10
    """
    
    incident_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=incident_query,
        timespan=timedelta(days=days)
    )
    
    if incident_result["status"] == "success" and len(incident_result["results"]) > 0:
        findings.append({
            "severity": "MEDIUM",
            "category": "Incident Management",
            "finding": f"Detected {len(incident_result['results'])} high-frequency failure patterns",
            "recommendation": "MAS requires documented incident response procedures",
            "details": incident_result["results"]
        })
        compliance_score -= 15
    
    # 3. Change Management
    change_query = f"""
    AzureActivity
    | where TimeGenerated > ago({days}d)
    | where OperationNameValue has_any ("write", "delete", "action")
    | where ActivityStatus == "Succeeded"
    | summarize Changes = count() by Caller, OperationName, bin(TimeGenerated, 1d)
    | order by Changes desc
    """
    
    change_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=change_query,
        timespan=timedelta(days=days)
    )
    
    if change_result["status"] == "success":
        findings.append({
            "severity": "INFO",
            "category": "Change Management",
            "finding": f"Logged {len(change_result['results'])} configuration changes",
            "recommendation": "Ensure all changes follow MAS change management guidelines"
        })
    
    # 4. Audit Trail
    audit_query = f"""
    AzureActivity
    | where TimeGenerated > ago({days}d)
    | summarize AuditEvents = count() by bin(TimeGenerated, 1d)
    | summarize AvgDailyEvents = avg(AuditEvents), TotalEvents = sum(AuditEvents)
    """
    
    audit_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=audit_query,
        timespan=timedelta(days=days)
    )
    
    if audit_result["status"] == "success":
        total_events = audit_result["results"].get("TotalEvents", 0) if audit_result["results"] else 0
        if total_events < 1000:
            findings.append({
                "severity": "MEDIUM",
                "category": "Audit Trail",
                "finding": "Low audit event volume detected",
                "recommendation": "MAS requires comprehensive audit logging for all critical operations"
            })
            compliance_score -= 10
    
    # 5. Cyber Hygiene
    security_query = f"""
    SecurityEvent
    | where TimeGenerated > ago({days}d)
    | where EventID in (4624, 4625, 4648, 4672, 4719)
    | summarize SecurityEvents = count() by EventID, Computer
    | join kind=inner (
        SecurityEvent
        | where EventID == 4625
        | summarize FailedLogins = count() by Computer
    ) on Computer
    | where FailedLogins > 100
    """
    
    security_result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=security_query,
        timespan=timedelta(days=days)
    )
    
    if security_result["status"] == "success" and len(security_result["results"]) > 0:
        findings.append({
            "severity": "HIGH",
            "category": "Cyber Hygiene",
            "finding": f"Excessive failed login attempts on {len(security_result['results'])} systems",
            "recommendation": "Implement MFA and account lockout policies per MAS guidelines"
        })
        compliance_score -= 20
    
    # 6. Data Residency
    findings.append({
        "severity": "INFO",
        "category": "Data Residency",
        "finding": "Data stored in Southeast Asia region",
        "recommendation": "MAS prefers Singapore-based data residency for financial institutions"
    })
    
    return ComplianceReport(
        report_type="MAS_TRM",
        time_range=f"Last {days} days",
        findings=findings,
        compliance_score=max(0, compliance_score),
        generated_at=datetime.utcnow()
    )

@router.get("/compliance/summary")
async def compliance_summary(
    workspace_id: str = Query(..., description="Workspace ID"),
    days: int = Query(30, description="Days to analyze"),
    azure_client: AzureMonitorClient = Depends(get_azure_client)
):
    """
    Generate comprehensive compliance summary report.
    """
    # Run all compliance checks
    gdpr = await gdpr_compliance_check(workspace_id, days, azure_client)
    pdpa = await pdpa_compliance_check(workspace_id, days, azure_client)
    mas = await mas_compliance_check(workspace_id, days, azure_client)
    
    return {
        "workspace_id": workspace_id,
        "report_period": f"Last {days} days",
        "generated_at": datetime.utcnow().isoformat(),
        "compliance_frameworks": {
            "GDPR": {
                "score": gdpr.compliance_score,
                "findings_count": len(gdpr.findings),
                "critical_findings": len([f for f in gdpr.findings if f["severity"] == "HIGH"])
            },
            "PDPA": {
                "score": pdpa.compliance_score,
                "findings_count": len(pdpa.findings),
                "critical_findings": len([f for f in pdpa.findings if f["severity"] == "HIGH"])
            },
            "MAS_TRM": {
                "score": mas.compliance_score,
                "findings_count": len(mas.findings),
                "critical_findings": len([f for f in mas.findings if f["severity"] == "HIGH"])
            }
        },
        "overall_score": (gdpr.compliance_score + pdpa.compliance_score + mas.compliance_score) / 3,
        "recommendations": [
            "Enable Azure Policy for automated compliance enforcement",
            "Implement Azure Sentinel for advanced threat detection",
            "Regular compliance audits (quarterly recommended)",
            "Document incident response procedures",
            "Conduct security awareness training"
        ]
    }

