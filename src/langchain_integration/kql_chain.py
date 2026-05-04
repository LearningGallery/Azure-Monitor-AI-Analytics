"""LangChain integration for natural language to KQL conversion."""

from typing import Dict, List, Optional, Any
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
from langchain_huggingface import HuggingFaceEndpoint
from langchain.memory import ConversationBufferMemory
import os
import logging

logger = logging.getLogger(__name__)

class KQLQueryGenerator:
    """Generate KQL queries from natural language using LLM."""
    
    # Common Log Analytics tables
    COMMON_TABLES = {
        "events": "Event",
        "syslog": "Syslog",
        "performance": "Perf",
        "heartbeat": "Heartbeat",
        "alerts": "Alert",
        "updates": "Update",
        "security": "SecurityEvent",
        "containers": "ContainerLog",
        "kubernetes": "KubePodInventory",
        "app_insights": "requests",
        "activity_log": "AzureActivity",
        "diagnostics": "AzureDiagnostics"
    }
    
    def __init__(self, hf_token: Optional[str] = None):
        """Initialize KQL generator."""
        self.hf_token = hf_token or os.getenv("HUGGINGFACE_API_KEY")
        
        # Initialize LLM
        self.llm = HuggingFaceEndpoint(
            repo_id="mistralai/Mistral-7B-Instruct-v0.2",
            huggingfacehub_api_token=self.hf_token,
            temperature=0.1,  # Low temperature for precise queries
            max_new_tokens=512
        )
        
        # KQL generation prompt
        self.kql_prompt = PromptTemplate(
            input_variables=["natural_query", "context", "available_tables"],
            template="""You are an expert in Azure Log Analytics and KQL (Kusto Query Language).

Available Tables:
{available_tables}

Context:
{context}

User Request: {natural_query}

Generate a valid KQL query that:
1. Uses proper KQL syntax
2. Includes appropriate time filters
3. Uses summarize/aggregation where needed
4. Includes only existing columns
5. Orders results logically

Return ONLY the KQL query without explanation.

KQL Query:"""
        )
        
        self.kql_chain = LLMChain(
            llm=self.llm,
            prompt=self.kql_prompt,
            verbose=True
        )
        
        # Memory for conversation context
        self.memory = ConversationBufferMemory(
            memory_key="chat_history",
            return_messages=True
        )
    
    async def generate_kql(
        self,
        natural_query: str,
        context: Optional[Dict[str, Any]] = None,
        table_schemas: Optional[Dict[str, List[str]]] = None
    ) -> Dict[str, Any]:
        """
        Generate KQL query from natural language.
        
        Args:
            natural_query: User's natural language query
            context: Additional context (workspace info, recent queries, etc.)
            table_schemas: Available table schemas
        
        Returns:
            Dictionary with generated query and metadata
        """
        # Build context string
        context_str = ""
        if context:
            if "workspace_name" in context:
                context_str += f"Workspace: {context['workspace_name']}\n"
            if "time_range" in context:
                context_str += f"Default time range: {context['time_range']}\n"
        
        # Build available tables string
        tables_str = "\n".join([
            f"- {name}: {table}" 
            for name, table in self.COMMON_TABLES.items()
        ])
        
        if table_schemas:
            tables_str += "\n\nTable Schemas:\n"
            for table, columns in table_schemas.items():
                tables_str += f"{table}: {', '.join(columns)}\n"
        
        try:
            # Generate query
            result = self.kql_chain.run(
                natural_query=natural_query,
                context=context_str,
                available_tables=tables_str
            )
            
            # Clean up the result
            kql_query = result.strip()
            
            # Remove markdown code blocks if present
            if kql_query.startswith("```"):
                kql_query = kql_query.split("```")
                if kql_query.startswith("kql"):
                    kql_query = kql_query[3:]
                kql_query = kql_query.strip()
            
            # Validate basic KQL syntax
            is_valid = self._validate_kql(kql_query)
            
            return {
                "status": "success",
                "query": kql_query,
                "natural_query": natural_query,
                "is_valid": is_valid,
                "warnings": [] if is_valid else ["Query may have syntax issues"]
            }
        
        except Exception as e:
            logger.error(f"Error generating KQL: {e}")
            return {
                "status": "error",
                "error": str(e),
                "query": None
            }
    
    def _validate_kql(self, query: str) -> bool:
        """Basic KQL syntax validation."""
        # Check for common KQL keywords
        kql_keywords = [
            "where", "summarize", "project", "extend", "join",
            "union", "let", "order", "top", "distinct"
        ]
        
        query_lower = query.lower()
        
        # Must contain at least one KQL keyword
        has_keyword = any(keyword in query_lower for keyword in kql_keywords)
        
        # Check for balanced parentheses
        balanced = query.count("(") == query.count(")")
        
        # Check for pipe operators
        has_pipe = "|" in query
        
        return has_keyword and balanced and (has_pipe or "let" in query_lower)
    
    async def explain_query(self, kql_query: str) -> str:
        """Explain what a KQL query does in plain English."""
        explain_prompt = PromptTemplate(
            input_variables=["query"],
            template="""Explain this KQL query in simple terms:

{query}

Explanation:"""
        )
        
        chain = LLMChain(llm=self.llm, prompt=explain_prompt)
        explanation = chain.run(query=kql_query)
        
        return explanation.strip()
    
    async def optimize_query(self, kql_query: str) -> Dict[str, Any]:
        """Suggest optimizations for a KQL query."""
        optimize_prompt = PromptTemplate(
            input_variables=["query"],
            template="""Analyze this KQL query for performance optimizations:

{query}

Provide:
1. Performance issues (if any)
2. Optimized version of the query
3. Explanation of improvements

Response:"""
        )
        
        chain = LLMChain(llm=self.llm, prompt=optimize_prompt)
        result = chain.run(query=kql_query)
        
        return {
            "original_query": kql_query,
            "analysis": result.strip()
        }

class KQLTemplates:
    """Pre-built KQL query templates."""
    
    @staticmethod
    def failed_logins(hours: int = 24) -> str:
        """Get failed login attempts."""
        return f"""
        SecurityEvent
        | where TimeGenerated > ago({hours}h)
        | where EventID == 4625  // Failed login
        | summarize FailedAttempts = count() by 
            Account, 
            Computer, 
            IpAddress,
            bin(TimeGenerated, 1h)
        | where FailedAttempts > 5
        | order by FailedAttempts desc
        """
    
    @staticmethod
    def high_cpu_vms(threshold: int = 80, hours: int = 1) -> str:
        """Get VMs with high CPU usage."""
        return f"""
        Perf
        | where TimeGenerated > ago({hours}h)
        | where ObjectName == "Processor" 
            and CounterName == "% Processor Time"
        | where CounterValue > {threshold}
        | summarize AvgCPU = avg(CounterValue) by 
            Computer,
            bin(TimeGenerated, 5m)
        | order by AvgCPU desc
        """
    
    @staticmethod
    def kubernetes_pod_failures(namespace: str = "default", hours: int = 24) -> str:
        """Get Kubernetes pod failures."""
        return f"""
        KubePodInventory
        | where TimeGenerated > ago({hours}h)
        | where Namespace == "{namespace}"
        | where PodStatus in ("Failed", "Unknown", "Pending")
        | summarize 
            FailureCount = count(),
            LastSeen = max(TimeGenerated)
            by 
            PodName,
            PodStatus,
            Namespace,
            ControllerName
        | order by FailureCount desc
        """
    
    @staticmethod
    def azure_activity_errors(hours: int = 24) -> str:
        """Get Azure Activity Log errors."""
        return f"""
        AzureActivity
        | where TimeGenerated > ago({hours}h)
        | where ActivityStatus == "Failed"
        | summarize 
            ErrorCount = count(),
            UniqueCallers = dcount(Caller)
            by 
            OperationName,
            ResourceGroup,
            bin(TimeGenerated, 1h)
        | order by ErrorCount desc
        """
    
    @staticmethod
    def application_errors(hours: int = 24, min_count: int = 10) -> str:
        """Get application errors from Application Insights."""
        return f"""
        requests
        | where timestamp > ago({hours}h)
        | where success == false
        | summarize 
            ErrorCount = count(),
            AvgDuration = avg(duration),
            UniqueUsers = dcount(user_Id)
            by 
            name,
            resultCode,
            bin(timestamp, 30m)
        | where ErrorCount > {min_count}
        | order by ErrorCount desc
        """
    
    @staticmethod
    def cost_analysis(days: int = 7) -> str:
        """Analyze log ingestion costs."""
        return f"""
        Usage
        | where TimeGenerated > ago({days}d)
        | where IsBillable == true
        | summarize 
            TotalGB = sum(Quantity) / 1000,
            EstimatedCostUSD = sum(Quantity) / 1000 * 2.30  // Approx \$2.30/GB
            by DataType
        | extend TotalGB = round(TotalGB, 2)
        | extend EstimatedCostUSD = round(EstimatedCostUSD, 2)
        | order by TotalGB desc
        """
