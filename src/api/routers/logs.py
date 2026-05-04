"""Log query endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import timedelta
import logging

from ..dependencies import get_azure_client, get_kql_generator
from ...connectors.azure_monitor import AzureMonitorClient
from ...langchain_integration.kql_chain import KQLQueryGenerator, KQLTemplates

logger = logging.getLogger(__name__)

router = APIRouter()

class LogQueryRequest(BaseModel):
    """Log query request model."""
    workspace_id: str = Field(..., description="Log Analytics Workspace ID")
    query: str = Field(..., description="KQL query")
    timespan_hours: Optional[int] = Field(24, description="Time range in hours")
    include_statistics: bool = Field(False, description="Include query statistics")

class NaturalLanguageQueryRequest(BaseModel):
    """Natural language query request."""
    workspace_id: str
    natural_query: str = Field(..., description="Natural language query")
    timespan_hours: Optional[int] = 24
    context: Optional[Dict[str, Any]] = None

@router.post("/query")
async def execute_query(
    request: LogQueryRequest,
    azure_client: AzureMonitorClient = Depends(get_azure_client)
):
    """Execute KQL query against Log Analytics workspace."""
    try:
        result = await azure_client.query_logs(
            workspace_id=request.workspace_id,
            query=request.query,
            timespan=timedelta(hours=request.timespan_hours),
            include_statistics=request.include_statistics
        )
        
        return result
    
    except Exception as e:
        logger.error(f"Error executing query: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/query/natural")
async def natural_language_query(
    request: NaturalLanguageQueryRequest,
    azure_client: AzureMonitorClient = Depends(get_azure_client),
    kql_generator: KQLQueryGenerator = Depends(get_kql_generator)
):
    """
    Execute natural language query.
    Converts natural language to KQL and executes it.
    """
    try:
        # Generate KQL from natural language
        generated = await kql_generator.generate_kql(
            natural_query=request.natural_query,
            context=request.context or {}
        )
        
        if generated["status"] != "success":
            raise HTTPException(
                status_code=400,
                detail=f"Failed to generate query: {generated.get('error')}"
            )
        
        kql_query = generated["query"]
        
        # Execute generated query
        result = await azure_client.query_logs(
            workspace_id=request.workspace_id,
            query=kql_query,
            timespan=timedelta(hours=request.timespan_hours)
        )
        
        return {
            "natural_query": request.natural_query,
            "generated_kql": kql_query,
            "is_valid": generated["is_valid"],
            "warnings": generated.get("warnings", []),
            "results": result
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing natural language query: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/query/explain")
async def explain_kql_query(
    query: str = Query(..., description="KQL query to explain"),
    kql_generator: KQLQueryGenerator = Depends(get_kql_generator)
):
    """Explain what a KQL query does in plain English."""
    try:
        explanation = await kql_generator.explain_query(query)
        
        return {
            "query": query,
            "explanation": explanation
        }
    
    except Exception as e:
        logger.error(f"Error explaining query: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/query/optimize")
async def optimize_kql_query(
    query: str = Query(..., description="KQL query to optimize"),
    kql_generator: KQLQueryGenerator = Depends(get_kql_generator)
):
    """Get optimization suggestions for a KQL query."""
    try:
        optimization = await kql_generator.optimize_query(query)
        
        return optimization
    
    except Exception as e:
        logger.error(f"Error optimizing query: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/templates")
async def get_query_templates():
    """Get pre-built KQL query templates."""
    return {
        "templates": [
            {
                "name": "failed_logins",
                "description": "Find failed login attempts",
                "parameters": ["hours"],
                "example": KQLTemplates.failed_logins(24)
            },
            {
                "name": "high_cpu_vms",
                "description": "Find VMs with high CPU usage",
                "parameters": ["threshold", "hours"],
                "example": KQLTemplates.high_cpu_vms(80, 1)
            },
            {
                "name": "kubernetes_pod_failures",
                "description": "Find Kubernetes pod failures",
                "parameters": ["namespace", "hours"],
                "example": KQLTemplates.kubernetes_pod_failures("default", 24)
            },
            {
                "name": "azure_activity_errors",
                "description": "Find Azure Activity Log errors",
                "parameters": ["hours"],
                "example": KQLTemplates.azure_activity_errors(24)
            },
            {
                "name": "application_errors",
                "description": "Find application errors",
                "parameters": ["hours", "min_count"],
                "example": KQLTemplates.application_errors(24, 10)
            },
            {
                "name": "cost_analysis",
                "description": "Analyze log ingestion costs",
                "parameters": ["days"],
                "example": KQLTemplates.cost_analysis(7)
            }
        ]
    }

@router.post("/templates/{template_name}")
async def execute_template(
    template_name: str,
    workspace_id: str = Query(..., description="Workspace ID"),
    parameters: Optional[Dict[str, Any]] = None,
    azure_client: AzureMonitorClient = Depends(get_azure_client)
):
    """Execute a pre-built query template."""
    params = parameters or {}
    
    # Map template names to functions
    templates = {
        "failed_logins": lambda: KQLTemplates.failed_logins(
            params.get("hours", 24)
        ),
        "high_cpu_vms": lambda: KQLTemplates.high_cpu_vms(
            params.get("threshold", 80),
            params.get("hours", 1)
        ),
        "kubernetes_pod_failures": lambda: KQLTemplates.kubernetes_pod_failures(
            params.get("namespace", "default"),
            params.get("hours", 24)
        ),
        "azure_activity_errors": lambda: KQLTemplates.azure_activity_errors(
            params.get("hours", 24)
        ),
        "application_errors": lambda: KQLTemplates.application_errors(
            params.get("hours", 24),
            params.get("min_count", 10)
        ),
        "cost_analysis": lambda: KQLTemplates.cost_analysis(
            params.get("days", 7)
        )
    }
    
    if template_name not in templates:
        raise HTTPException(
            status_code=404,
            detail=f"Template '{template_name}' not found"
        )
    
    try:
        query = templates[template_name]()
        
        result = await azure_client.query_logs(
            workspace_id=workspace_id,
            query=query,
            timespan=timedelta(hours=params.get("hours", 24))
        )
        
        return {
            "template": template_name,
            "parameters": params,
            "query": query,
            "results": result
        }
    
    except Exception as e:
        logger.error(f"Error executing template: {e}")
        raise HTTPException(status_code=500, detail=str(e))

