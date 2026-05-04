"""Azure Monitor and Log Analytics client."""

from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
from azure.identity import DefaultAzureCredential, ClientSecretCredential
from azure.monitor.query import LogsQueryClient, LogsQueryStatus
from azure.mgmt.loganalytics import LogAnalyticsManagementClient
from azure.core.exceptions import HttpResponseError
import logging
import os

logger = logging.getLogger(__name__)

class AzureMonitorClient:
    """Client for Azure Monitor and Log Analytics."""
    
    def __init__(
        self,
        subscription_id: Optional[str] = None,
        tenant_id: Optional[str] = None,
        client_id: Optional[str] = None,
        client_secret: Optional[str] = None
    ):
        """Initialize Azure Monitor client."""
        self.subscription_id = subscription_id or os.getenv("AZURE_SUBSCRIPTION_ID")
        
        # Authentication
        if client_id and client_secret and tenant_id:
            self.credential = ClientSecretCredential(
                tenant_id=tenant_id,
                client_id=client_id,
                client_secret=client_secret
            )
        else:
            # Use Managed Identity or Azure CLI credentials
            self.credential = DefaultAzureCredential()
        
        # Initialize clients
        self.logs_client = LogsQueryClient(self.credential)
        self.mgmt_client = LogAnalyticsManagementClient(
            credential=self.credential,
            subscription_id=self.subscription_id
        )
    
    async def query_logs(
        self,
        workspace_id: str,
        query: str,
        timespan: Optional[timedelta] = None,
        server_timeout: int = 300,
        include_statistics: bool = False,
        include_visualization: bool = False
    ) -> Dict[str, Any]:
        """
        Execute KQL query against Log Analytics workspace.
        
        Args:
            workspace_id: Log Analytics Workspace ID
            query: KQL query string
            timespan: Time range for query (default: last 24 hours)
            server_timeout: Query timeout in seconds
            include_statistics: Include query statistics
            include_visualization: Include visualization info
        
        Returns:
            Query results with metadata
        """
        if timespan is None:
            timespan = timedelta(hours=24)
        
        try:
            logger.info(f"Executing query on workspace {workspace_id}")
            logger.debug(f"Query: {query}")
            
            response = self.logs_client.query_workspace(
                workspace_id=workspace_id,
                query=query,
                timespan=timespan,
                server_timeout=server_timeout,
                include_statistics=include_statistics,
                include_visualization=include_visualization
            )
            
            if response.status == LogsQueryStatus.SUCCESS:
                # Extract results
                results = []
                for table in response.tables:
                    columns = [col.name for col in table.columns]
                    for row in table.rows:
                        results.append(dict(zip(columns, row)))
                
                return {
                    "status": "success",
                    "row_count": len(results),
                    "results": results,
                    "statistics": response.statistics if include_statistics else None,
                    "visualization": response.visualization if include_visualization else None
                }
            
            elif response.status == LogsQueryStatus.PARTIAL:
                logger.warning("Query returned partial results")
                error_info = response.partial_error
                
                return {
                    "status": "partial",
                    "error": str(error_info),
                    "results": []
                }
            
            else:
                logger.error(f"Query failed with status: {response.status}")
                return {
                    "status": "failed",
                    "error": "Query execution failed",
                    "results": []
                }
        
        except HttpResponseError as e:
            logger.error(f"HTTP error querying logs: {e}")
            return {
                "status": "error",
                "error": str(e),
                "results": []
            }
        
        except Exception as e:
            logger.error(f"Unexpected error querying logs: {e}")
            return {
                "status": "error",
                "error": str(e),
                "results": []
            }
    
    async def query_multiple_workspaces(
        self,
        workspace_ids: List[str],
        query: str,
        timespan: Optional[timedelta] = None
    ) -> Dict[str, Any]:
        """
        Query multiple workspaces (cross-workspace query).
        
        Args:
            workspace_ids: List of workspace IDs
            query: KQL query with workspace() function
            timespan: Time range
        
        Returns:
            Aggregated results from all workspaces
        """
        if timespan is None:
            timespan = timedelta(hours=24)
        
        # Primary workspace is the first one
        primary_workspace = workspace_ids
        
        # Build cross-workspace query
        workspace_refs = ", ".join([f"'{ws}'" for ws in workspace_ids[1:]])
        cross_workspace_query = f"""
        union withsource=WorkspaceId
        workspace({workspace_refs}).{query},
        {query}
        """
        
        return await self.query_logs(
            workspace_id=primary_workspace,
            query=cross_workspace_query,
            timespan=timespan
        )
    
    async def get_workspace_metadata(
        self,
        resource_group: str,
        workspace_name: str
    ) -> Dict[str, Any]:
        """Get Log Analytics workspace metadata."""
        try:
            workspace = self.mgmt_client.workspaces.get(
                resource_group_name=resource_group,
                workspace_name=workspace_name
            )
            
            return {
                "id": workspace.id,
                "name": workspace.name,
                "customer_id": workspace.customer_id,
                "sku": workspace.sku.name,
                "retention_days": workspace.retention_in_days,
                "daily_quota_gb": workspace.workspace_capping.daily_quota_gb,
                "location": workspace.location,
                "provisioning_state": workspace.provisioning_state
            }
        
        except Exception as e:
            logger.error(f"Error getting workspace metadata: {e}")
            raise
    
    async def get_workspace_usage(
        self,
        workspace_id: str,
        days: int = 7
    ) -> Dict[str, Any]:
        """
        Get workspace data ingestion usage.
        
        Args:
            workspace_id: Workspace ID
            days: Number of days to look back
        
        Returns:
            Usage statistics
        """
        query = f"""
        Usage
        | where TimeGenerated > ago({days}d)
        | where IsBillable == true
        | summarize 
            TotalGB = sum(Quantity) / 1000,
            AvgDailyGB = avg(Quantity) / 1000
            by DataType
        | order by TotalGB desc
        """
        
        result = await self.query_logs(
            workspace_id=workspace_id,
            query=query,
            timespan=timedelta(days=days)
        )
        
        return result
    
    async def get_table_schema(
        self,
        workspace_id: str,
        table_name: str
    ) -> List[Dict[str, str]]:
        """Get schema of a Log Analytics table."""
        query = f"""
        {table_name}
        | getschema
        | project ColumnName, DataType
        """
        
        result = await self.query_logs(
            workspace_id=workspace_id,
            query=query,
            timespan=timedelta(hours=1)
        )
        
        if result["status"] == "success":
            return result["results"]
        
        return []
