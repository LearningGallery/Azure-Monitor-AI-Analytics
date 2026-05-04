"""Integration tests for Azure Monitor client."""

import pytest
from unittest.mock import AsyncMock, patch
from datetime import timedelta
from src.connectors.azure_monitor import AzureMonitorClient

@pytest.fixture
def azure_client():
    """Create Azure Monitor client."""
    with patch('src.connectors.azure_monitor.DefaultAzureCredential'):
        client = AzureMonitorClient(subscription_id="test-sub")
        return client

@pytest.mark.asyncio
@pytest.mark.integration
async def test_query_logs(azure_client):
    """Test log query execution."""
    # Mock the response
    mock_response = AsyncMock()
    mock_response.status = "SUCCESS"
    mock_response.tables = [
        MagicMock(
            columns=[MagicMock(name="Computer"), MagicMock(name="Count")],
            rows=[["Server1", 10], ["Server2", 5]]
        )
    ]
    
    azure_client.logs_client.query_workspace = AsyncMock(return_value=mock_response)
    
    result = await azure_client.query_logs(
        workspace_id="test-workspace",
        query="Heartbeat | summarize Count = count() by Computer",
        timespan=timedelta(hours=1)
    )
    
    assert result["status"] == "success"
    assert result["row_count"] == 2
    assert len(result["results"]) == 2

@pytest.mark.asyncio
@pytest.mark.integration
async def test_query_multiple_workspaces(azure_client):
    """Test cross-workspace query."""
    mock_response = AsyncMock()
    mock_response.status = "SUCCESS"
    mock_response.tables = [MagicMock(columns=[], rows=[])]
    
    azure_client.logs_client.query_workspace = AsyncMock(return_value=mock_response)
    
    result = await azure_client.query_multiple_workspaces(
        workspace_ids=["workspace1", "workspace2"],
        query="Heartbeat | summarize count()"
    )
    
    assert result["status"] == "success"
    # Verify cross-workspace query was constructed
    assert azure_client.logs_client.query_workspace.called
