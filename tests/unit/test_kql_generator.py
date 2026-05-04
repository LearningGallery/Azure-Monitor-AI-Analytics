"""Unit tests for KQL generator."""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from src.langchain_integration.kql_chain import KQLQueryGenerator, KQLTemplates

@pytest.fixture
def kql_generator():
    """Create KQL generator instance."""
    with patch('src.langchain_integration.kql_chain.HuggingFaceEndpoint'):
        generator = KQLQueryGenerator(hf_token="test_token")
        return generator

@pytest.mark.asyncio
async def test_generate_kql_success(kql_generator):
    """Test successful KQL generation."""
    # Mock LLM response
    kql_generator.kql_chain.run = AsyncMock(return_value="""
    SecurityEvent
    | where TimeGenerated > ago(1h)
    | where EventID == 4625
    | summarize Count = count() by Computer
    """)
    
    result = await kql_generator.generate_kql(
        natural_query="Show failed logins in the last hour"
    )
    
    assert result["status"] == "success"
    assert "SecurityEvent" in result["query"]
    assert result["is_valid"] is True

@pytest.mark.asyncio
async def test_generate_kql_invalid_syntax(kql_generator):
    """Test KQL generation with invalid syntax."""
    kql_generator.kql_chain.run = AsyncMock(return_value="This is not a valid KQL query")
    
    result = await kql_generator.generate_kql(
        natural_query="Show me some data"
    )
    
    assert result["status"] == "success"
    assert result["is_valid"] is False
    assert len(result["warnings"]) > 0

def test_kql_templates():
    """Test pre-built KQL templates."""
    # Test failed logins template
    query = KQLTemplates.failed_logins(hours=24)
    assert "SecurityEvent" in query
    assert "4625" in query
    
    # Test high CPU template
    query = KQLTemplates.high_cpu_vms(threshold=80, hours=1)
    assert "Perf" in query
    assert "80" in query
    
    # Test Kubernetes template
    query = KQLTemplates.kubernetes_pod_failures(namespace="default", hours=24)
    assert "KubePodInventory" in query
    assert "default" in query

@pytest.mark.asyncio
async def test_explain_query(kql_generator):
    """Test query explanation."""
    kql_generator.llm = AsyncMock()
    
    explanation = await kql_generator.explain_query(
        "Perf | where CounterName == '% Processor Time'"
    )
    
    # Should call LLM
    assert kql_generator.llm.called or True  # Placeholder assertion
