"""FastAPI application for AI Log Analytics."""

from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from typing import Optional, List
import logging
import os

from .routers import logs, analytics, workspaces, compliance
from ..connectors.azure_monitor import AzureMonitorClient
from ..langchain_integration.kql_chain import KQLQueryGenerator
from .dependencies import get_azure_client, get_kql_generator

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    logger.info("Starting AI Log Analytics API...")
    
    # Initialize clients
    app.state.azure_client = AzureMonitorClient()
    app.state.kql_generator = KQLQueryGenerator()
    
    logger.info("API started successfully")
    
    yield
    
    logger.info("Shutting down API...")

# Create FastAPI app
app = FastAPI(
    title="Azure Log Analytics AI",
    description="Enterprise AI-Powered Log Analytics for Azure Infrastructure",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(logs.router, prefix="/api/v1/logs", tags=["Logs"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
app.include_router(workspaces.router, prefix="/api/v1/workspaces", tags=["Workspaces"])
app.include_router(compliance.router, prefix="/api/v1/compliance", tags=["Compliance"])

@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "Azure Log Analytics AI",
        "version": "1.0.0",
        "status": "healthy"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "azure_connection": "ok"
    }

@app.get("/api/v1/tables")
async def list_tables(
    workspace_id: str = Query(..., description="Workspace ID"),
    azure_client: AzureMonitorClient = Depends(get_azure_client)
):
    """List available tables in workspace."""
    query = """
    search *
    | distinct \$table
    | sort by \$table asc
    """
    
    result = await azure_client.query_logs(
        workspace_id=workspace_id,
        query=query
    )
    
    if result["status"] == "success":
        tables = [row["\$table"] for row in result["results"]]
        return {"tables": tables}
    
    raise HTTPException(status_code=500, detail="Failed to list tables")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
