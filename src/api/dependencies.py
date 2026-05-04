"""FastAPI dependencies."""

from fastapi import Request
from typing import Optional

from ..connectors.azure_monitor import AzureMonitorClient
from ..langchain_integration.kql_chain import KQLQueryGenerator
from ..langchain_integration.log_analyzer import LogAnalyzer

async def get_azure_client(request: Request) -> AzureMonitorClient:
    """Get Azure Monitor client from app state."""
    return request.app.state.azure_client

async def get_kql_generator(request: Request) -> KQLQueryGenerator:
    """Get KQL generator from app state."""
    return request.app.state.kql_generator

async def get_log_analyzer(request: Request) -> Optional[LogAnalyzer]:
    """Get log analyzer from app state."""
    if not hasattr(request.app.state, "log_analyzer"):
        request.app.state.log_analyzer = LogAnalyzer()
    return request.app.state.log_analyzer
