"""Advanced log analysis using LangChain and AI."""

from typing import List, Dict, Any, Optional
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
from langchain_huggingface import HuggingFaceEndpoint
from sentence_transformers import SentenceTransformer
from sklearn.cluster import DBSCAN
import numpy as np
import pandas as pd
import logging
import os

from .prompts import ROOT_CAUSE_TEMPLATE, ANOMALY_EXPLANATION_TEMPLATE

logger = logging.getLogger(__name__)

class LogAnalyzer:
    """Advanced AI-powered log analysis."""
    
    def __init__(self, hf_token: Optional[str] = None):
        """Initialize log analyzer."""
        self.hf_token = hf_token or os.getenv("HUGGINGFACE_API_KEY")
        
        # Initialize LLM
        self.llm = HuggingFaceEndpoint(
            repo_id="mistralai/Mistral-7B-Instruct-v0.2",
            huggingfacehub_api_token=self.hf_token,
            temperature=0.3,
            max_new_tokens=1024
        )
        
        # Initialize embedding model for pattern detection
        self.embedder = SentenceTransformer('all-MiniLM-L6-v2')
        
        # Root cause analysis chain
        self.root_cause_prompt = PromptTemplate(
            input_variables=["error_logs", "service_name", "environment", "timestamp", "related_services"],
            template=ROOT_CAUSE_TEMPLATE
        )
        
        self.root_cause_chain = LLMChain(
            llm=self.llm,
            prompt=self.root_cause_prompt,
            verbose=True
        )
    
    async def analyze_root_cause(
        self,
        error_logs: List[str],
        context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Perform root cause analysis on error logs.
        
        Args:
            error_logs: List of error log messages
            context: Context information (service, environment, etc.)
        
        Returns:
            Root cause analysis report
        """
        try:
            # Prepare logs for analysis (limit to avoid token limits)
            logs_text = "\n".join(error_logs[:10])
            
            # Extract context
            service_name = context.get("service", "Unknown")
            environment = context.get("environment", "Production")
            timestamp = context.get("timestamp", "Recent")
            related_services = context.get("related_services", "N/A")
            
            # Run analysis
            analysis = self.root_cause_chain.run(
                error_logs=logs_text,
                service_name=service_name,
                environment=environment,
                timestamp=timestamp,
                related_services=related_services
            )
            
            return {
                "status": "success",
                "analysis": analysis,
                "logs_analyzed": len(error_logs),
                "context": context
            }
        
        except Exception as e:
            logger.error(f"Error in root cause analysis: {e}")
            return {
                "status": "error",
                "error": str(e)
            }
    
    async def detect_anomalies(
        self,
        data: List[Dict[str, Any]],
        metric_name: str
    ) -> Dict[str, Any]:
        """
        Detect anomalies in time-series data.
        
        Args:
            data: List of data points with TimeGenerated and CounterValue
            metric_name: Name of the metric being analyzed
        
        Returns:
            Anomaly detection results
        """
        try:
            # Convert to DataFrame
            df = pd.DataFrame(data)
            
            if df.empty or 'CounterValue' not in df.columns:
                return {
                    "status": "error",
                    "error": "Invalid data format"
                }
            
            # Calculate statistics
            values = df['CounterValue'].values
            mean = np.mean(values)
            std = np.std(values)
            
            # Z-score based anomaly detection
            z_scores = np.abs((values - mean) / std)
            threshold = 3.0  # 3 standard deviations
            
            anomalies = []
            for idx, (z_score, row) in enumerate(zip(z_scores, data)):
                if z_score > threshold:
                    anomalies.append({
                        "timestamp": row.get("TimeGenerated"),
                        "value": row.get("CounterValue"),
                        "z_score": float(z_score),
                        "deviation_percent": float((row.get("CounterValue") - mean) / mean * 100),
                        "computer": row.get("Computer", "Unknown")
                    })
            
            # Generate AI explanation for anomalies
            if anomalies:
                explanation = await self._explain_anomaly(
                    metric_name=metric_name,
                    normal_range=f"{mean:.2f} ± {std:.2f}",
                    anomalies=anomalies[:5]  # Top 5 anomalies
                )
            else:
                explanation = "No anomalies detected in the data."
            
            return {
                "status": "success",
                "metric": metric_name,
                "anomalies_count": len(anomalies),
                "anomalies": anomalies,
                "statistics": {
                    "mean": float(mean),
                    "std": float(std),
                    "min": float(np.min(values)),
                    "max": float(np.max(values)),
                    "data_points": len(values)
                },
                "explanation": explanation
            }
        
        except Exception as e:
            logger.error(f"Error detecting anomalies: {e}")
            return {
                "status": "error",
                "error": str(e)
            }
    
    async def _explain_anomaly(
        self,
        metric_name: str,
        normal_range: str,
        anomalies: List[Dict[str, Any]]
    ) -> str:
        """Generate AI explanation for detected anomalies."""
        try:
            # Prepare anomaly data
            anomaly_summary = "\n".join([
                f"- {a['timestamp']}: {a['value']} ({a['deviation_percent']:.1f}% deviation) on {a['computer']}"
                for a in anomalies
            ])
            
            prompt = PromptTemplate(
                input_variables=["metric_name", "normal_range", "anomalies"],
                template=ANOMALY_EXPLANATION_TEMPLATE
            )
            
            chain = LLMChain(llm=self.llm, prompt=prompt)
            
            explanation = chain.run(
                metric_name=metric_name,
                normal_range=normal_range,
                current_value=anomalies['value'],
                deviation=f"{anomalies['deviation_percent']:.1f}",
                timestamp=anomalies['timestamp'],
                context=anomaly_summary
            )
            
            return explanation.strip()
        
        except Exception as e:
            logger.error(f"Error explaining anomaly: {e}")
            return f"Anomalies detected but explanation failed: {str(e)}"
    
    async def detect_patterns(
        self,
        messages: List[str],
        timeframe: str
    ) -> Dict[str, Any]:
        """
        Detect recurring patterns in log messages using embeddings.
        
        Args:
            messages: List of log messages
            timeframe: Time range description
        
        Returns:
            Detected patterns
        """
        try:
            if not messages:
                return {
                    "status": "error",
                    "error": "No messages provided"
                }
            
            # Generate embeddings
            embeddings = self.embedder.encode(messages)
            
            # Cluster similar messages
            clustering = DBSCAN(eps=0.5, min_samples=3, metric='cosine')
            labels = clustering.fit_predict(embeddings)
            
            # Group messages by cluster
            patterns = {}
            for idx, label in enumerate(labels):
                if label == -1:  # Noise
                    continue
                
                if label not in patterns:
                    patterns[label] = []
                
                patterns[label].append(messages[idx])
            
            # Analyze patterns with AI
            pattern_analysis = []
            for pattern_id, pattern_messages in patterns.items():
                if len(pattern_messages) < 3:
                    continue
                
                # Get representative message
                representative = pattern_messages
                
                pattern_analysis.append({
                    "pattern_id": int(pattern_id),
                    "frequency": len(pattern_messages),
                    "representative_message": representative,
                    "sample_messages": pattern_messages[:3]
                })
            
            # Sort by frequency
            pattern_analysis.sort(key=lambda x: x['frequency'], reverse=True)
            
            # Generate AI insights
            if pattern_analysis:
                insights = await self._generate_pattern_insights(
                    patterns=pattern_analysis[:5],  # Top 5 patterns
                    timeframe=timeframe
                )
            else:
                insights = "No significant recurring patterns detected."
            
            return {
                "status": "success",
                "patterns_count": len(pattern_analysis),
                "patterns": pattern_analysis,
                "insights": insights,
                "messages_analyzed": len(messages)
            }
        
        except Exception as e:
            logger.error(f"Error detecting patterns: {e}")
            return {
                "status": "error",
                "error": str(e)
            }
    
    async def _generate_pattern_insights(
        self,
        patterns: List[Dict[str, Any]],
        timeframe: str
    ) -> str:
        """Generate AI insights for detected patterns."""
        try:
            patterns_summary = "\n".join([
                f"Pattern {p['pattern_id']}: {p['frequency']} occurrences - '{p['representative_message']}'"
                for p in patterns
            ])
            
            prompt = PromptTemplate(
                input_variables=["patterns", "timeframe"],
                template="""Analyze these recurring log patterns from {timeframe}:

{patterns}

Provide insights on:
1. What these patterns indicate about system health
2. Which patterns require immediate attention
3. Potential root causes
4. Recommended actions

Analysis:"""
            )
            
            chain = LLMChain(llm=self.llm, prompt=prompt)
            
            insights = chain.run(
                patterns=patterns_summary,
                timeframe=timeframe
            )
            
            return insights.strip()
        
        except Exception as e:
            logger.error(f"Error generating pattern insights: {e}")
            return f"Pattern analysis failed: {str(e)}"
    
    async def predict_incidents(
        self,
        historical_data: List[Dict[str, Any]],
        service_name: str
    ) -> Dict[str, Any]:
        """
        Predict potential incidents based on historical patterns.
        
        Args:
            historical_data: Historical error/incident data
            service_name: Name of the service
        
        Returns:
            Incident prediction
        """
        try:
            if not historical_data:
                return {
                    "status": "error",
                    "error": "No historical data provided"
                }
            
            # Convert to DataFrame
            df = pd.DataFrame(historical_data)
            
            # Calculate trends
            if 'ErrorCount' in df.columns:
                error_trend = df['ErrorCount'].values
                
                # Simple moving average
                window = min(5, len(error_trend))
                if len(error_trend) >= window:
                    moving_avg = pd.Series(error_trend).rolling(window=window).mean()
                    current_avg = moving_avg.iloc[-1] if len(moving_avg) > 0 else 0
                    previous_avg = moving_avg.iloc[-window] if len(moving_avg) >= window else 0
                    
                    trend_increase = (current_avg - previous_avg) / previous_avg * 100 if previous_avg > 0 else 0
                    
                    # Predict incident likelihood
                    if trend_increase > 50:
                        risk_level = "HIGH"
                        likelihood = 0.8
                    elif trend_increase > 20:
                        risk_level = "MEDIUM"
                        likelihood = 0.5
                    else:
                        risk_level = "LOW"
                        likelihood = 0.2
                    
                    # Generate AI prediction explanation
                    prediction_prompt = PromptTemplate(
                        input_variables=["service_name", "trend_increase", "risk_level", "current_avg"],
                        template="""Based on historical data for {service_name}:

Current error rate: {current_avg:.1f} errors/hour
Trend: {trend_increase:.1f}% increase
Risk Level: {risk_level}

Predict:
1. Likelihood of incident in next 24 hours
2. Potential causes
3. Preventive actions
4. Monitoring focus areas

Prediction:"""
                    )
                    
                    chain = LLMChain(llm=self.llm, prompt=prediction_prompt)
                    
                    prediction_text = chain.run(
                        service_name=service_name,
                        trend_increase=trend_increase,
                        risk_level=risk_level,
                        current_avg=current_avg
                    )
                    
                    return {
                        "status": "success",
                        "service": service_name,
                        "risk_level": risk_level,
                        "incident_likelihood": likelihood,
                        "trend_increase_percent": float(trend_increase),
                        "current_error_rate": float(current_avg),
                        "prediction": prediction_text.strip(),
                        "data_points_analyzed": len(historical_data)
                    }
            
            return {
                "status": "error",
                "error": "Insufficient data for prediction"
            }
        
        except Exception as e:
            logger.error(f"Error predicting incidents: {e}")
            return {
                "status": "error",
                "error": str(e)
            }
