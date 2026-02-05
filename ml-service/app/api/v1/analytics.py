"""
Analytics and insights API endpoints.
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.core.logging import get_logger
from app.core.security import get_api_key
from app.services.analytics_service import AnalyticsService

logger = get_logger(__name__)
router = APIRouter()


# Request/Response Models
class SentimentAnalysisRequest(BaseModel):
    """Request for sentiment analysis."""
    text: str = Field(..., min_length=1, max_length=5000)
    context: Optional[str] = Field(None, description="Context: review, chat, complaint")


class SentimentAnalysisResponse(BaseModel):
    """Sentiment analysis response."""
    success: bool = True
    message: str = "Sentiment analyzed successfully"
    sentiment: str
    score: float
    confidence: float
    emotions: dict
    keywords: List[str]


class FraudCheckRequest(BaseModel):
    """Request for fraud detection."""
    order_id: Optional[str] = None
    user_id: str
    order_data: dict


class FraudCheckResponse(BaseModel):
    """Fraud check response."""
    success: bool = True
    message: str = "Fraud check completed"
    is_suspicious: bool
    risk_score: float
    risk_level: str
    flags: List[str]
    recommendations: List[str]


class InsightsRequest(BaseModel):
    """Request for business insights."""
    metric: str = Field(..., description="Metric: orders, revenue, churn, satisfaction")
    time_range: str = Field("7d", description="Time range: 1d, 7d, 30d, 90d")
    segment: Optional[str] = Field(None, description="Segment: service_type, location, user_type")


class InsightsResponse(BaseModel):
    """Business insights response."""
    success: bool = True
    message: str = "Insights generated successfully"
    metric: str
    current_value: float
    trend: str
    change_percent: float
    insights: List[dict]
    recommendations: List[str]


@router.post("/sentiment", response_model=SentimentAnalysisResponse)
async def analyze_sentiment(
    request: SentimentAnalysisRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Analyze sentiment of text (reviews, chat messages, complaints).
    
    Returns:
    - Sentiment: positive, negative, neutral
    - Confidence score
    - Detected emotions
    - Key phrases
    """
    try:
        service = AnalyticsService()
        analysis = await service.analyze_sentiment(
            text=request.text,
            context=request.context
        )
        
        response = SentimentAnalysisResponse(
            sentiment=analysis["sentiment"],
            score=analysis["score"],
            confidence=analysis["confidence"],
            emotions=analysis["emotions"],
            keywords=analysis["keywords"]
        )
        
        logger.info(
            "Analyzed sentiment",
            sentiment=analysis["sentiment"],
            score=analysis["score"]
        )
        
        return response
        
    except Exception as e:
        logger.error("Sentiment analysis failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to analyze sentiment: {str(e)}"
        )


@router.post("/fraud-check", response_model=FraudCheckResponse)
async def check_fraud(
    request: FraudCheckRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Check order/user for fraudulent activity.
    
    Analyzes:
    - Order patterns
    - User behavior anomalies
    - Payment information
    - Delivery address patterns
    - Historical fraud indicators
    """
    try:
        service = AnalyticsService()
        fraud_check = await service.check_fraud(
            user_id=request.user_id,
            order_data=request.order_data,
            order_id=request.order_id
        )
        
        # Determine risk level
        risk_level = "low"
        if fraud_check["risk_score"] >= 0.7:
            risk_level = "high"
        elif fraud_check["risk_score"] >= 0.4:
            risk_level = "medium"
        
        response = FraudCheckResponse(
            is_suspicious=fraud_check["is_suspicious"],
            risk_score=fraud_check["risk_score"],
            risk_level=risk_level,
            flags=fraud_check["flags"],
            recommendations=fraud_check["recommendations"]
        )
        
        logger.info(
            "Fraud check completed",
            user_id=request.user_id,
            order_id=request.order_id,
            risk_score=fraud_check["risk_score"],
            suspicious=fraud_check["is_suspicious"]
        )
        
        return response
        
    except Exception as e:
        logger.error("Fraud check failed", user_id=request.user_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to check fraud: {str(e)}"
        )


@router.post("/insights", response_model=InsightsResponse)
async def get_insights(
    request: InsightsRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Get business insights and analytics.
    
    Provides:
    - Trend analysis
    - Performance metrics
    - Actionable recommendations
    - Anomaly detection
    """
    try:
        service = AnalyticsService()
        insights = await service.get_insights(
            metric=request.metric,
            time_range=request.time_range,
            segment=request.segment
        )
        
        response = InsightsResponse(
            metric=request.metric,
            current_value=insights["current_value"],
            trend=insights["trend"],
            change_percent=insights["change_percent"],
            insights=insights["insights"],
            recommendations=insights["recommendations"]
        )
        
        logger.info(
            "Generated insights",
            metric=request.metric,
            trend=insights["trend"]
        )
        
        return response
        
    except Exception as e:
        logger.error("Insights generation failed", metric=request.metric, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate insights: {str(e)}"
        )
