"""
Analytics service for sentiment analysis, fraud detection, and insights.
"""
from typing import Dict, List, Optional

from sqlalchemy import text

from app.core.logging import get_logger
from app.db.postgres import AsyncSessionLocal

logger = get_logger(__name__)


class AnalyticsService:
    """Service for analytics and insights."""
    
    def __init__(self):
        self.logger = logger
    
    async def analyze_sentiment(
        self,
        text: str,
        context: Optional[str] = None
    ) -> Dict:
        """
        Analyze sentiment of text.
        
        For production, use a pre-trained model like:
        - BERT for sentiment
        - DistilBERT for faster inference
        - Custom fine-tuned model
        
        This is a simplified implementation.
        """
        try:
            # Simple keyword-based sentiment analysis
            # In production, use transformers library
            
            positive_words = [
                'good', 'great', 'excellent', 'amazing', 'love', 'best',
                'delicious', 'fast', 'friendly', 'perfect', 'wonderful'
            ]
            
            negative_words = [
                'bad', 'terrible', 'awful', 'worst', 'slow', 'cold',
                'rude', 'late', 'wrong', 'disgusting', 'horrible'
            ]
            
            text_lower = text.lower()
            
            # Count positive and negative words
            positive_count = sum(1 for word in positive_words if word in text_lower)
            negative_count = sum(1 for word in negative_words if word in text_lower)
            
            # Calculate sentiment score
            total = positive_count + negative_count
            if total == 0:
                sentiment = "neutral"
                score = 0.5
            elif positive_count > negative_count:
                sentiment = "positive"
                score = 0.5 + (positive_count / (total * 2))
            else:
                sentiment = "negative"
                score = 0.5 - (negative_count / (total * 2))
            
            # Extract keywords (simple approach)
            words = text_lower.split()
            keywords = [
                word for word in words
                if len(word) > 4 and word not in ['about', 'there', 'their', 'would', 'could']
            ][:5]
            
            # Detect emotions (simplified)
            emotions = {
                "joy": positive_count > 0,
                "anger": any(word in text_lower for word in ['angry', 'mad', 'furious']),
                "sadness": any(word in text_lower for word in ['sad', 'disappointed']),
                "surprise": any(word in text_lower for word in ['wow', 'amazing', 'surprised'])
            }
            
            return {
                "sentiment": sentiment,
                "score": round(score, 2),
                "confidence": 0.75,  # Would be from model
                "emotions": emotions,
                "keywords": keywords
            }
            
        except Exception as e:
            self.logger.error("Sentiment analysis failed", error=str(e))
            return {
                "sentiment": "neutral",
                "score": 0.5,
                "confidence": 0.0,
                "emotions": {},
                "keywords": []
            }
    
    async def check_fraud(
        self,
        user_id: str,
        order_data: Dict,
        order_id: Optional[str] = None
    ) -> Dict:
        """
        Check for fraudulent activity.
        
        Analyzes patterns and anomalies.
        """
        try:
            async with AsyncSessionLocal() as session:
                # Get user order history
                query = text("""
                    SELECT COUNT(*) as total_orders,
                        COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders,
                        AVG("totalAmount") as avg_amount,
                        MAX("createdAt") as last_order
                    FROM orders
                    WHERE "customerId" = :user_id
                """)
                
                result = await session.execute(query, {"user_id": user_id})
                user_history = result.fetchone()
                
                # Calculate risk score
                risk_score = 0.0
                flags = []
                
                # Flag 1: New user with high-value order
                total_orders = user_history[0] if user_history else 0
                order_amount = order_data.get('total_amount', 0)
                
                if total_orders == 0 and order_amount > 100:
                    risk_score += 0.3
                    flags.append("New user with high-value order")
                
                # Flag 2: High cancellation rate
                if total_orders > 0:
                    cancellation_rate = user_history[1] / total_orders
                    if cancellation_rate > 0.5:
                        risk_score += 0.2
                        flags.append("High cancellation rate")
                
                # Flag 3: Order amount significantly higher than average
                if total_orders > 0 and user_history[2]:
                    avg_amount = user_history[2]
                    if order_amount > avg_amount * 3:
                        risk_score += 0.2
                        flags.append("Unusually high order amount")
                
                # Flag 4: Multiple orders in short time
                # (Would need more complex query)
                
                # Flag 5: Suspicious delivery address patterns
                # (Would need geolocation analysis)
                
                is_suspicious = risk_score >= 0.5
                
                # Generate recommendations
                recommendations = []
                if is_suspicious:
                    recommendations.extend([
                        "Require payment verification",
                        "Contact customer for confirmation",
                        "Monitor order closely"
                    ])
                    if risk_score >= 0.7:
                        recommendations.append("Consider blocking order")
                
                return {
                    "is_suspicious": is_suspicious,
                    "risk_score": round(risk_score, 2),
                    "flags": flags,
                    "recommendations": recommendations
                }
                
        except Exception as e:
            self.logger.error("Fraud check failed", error=str(e))
            return {
                "is_suspicious": False,
                "risk_score": 0.0,
                "flags": [],
                "recommendations": []
            }
    
    async def get_insights(
        self,
        metric: str,
        time_range: str,
        segment: Optional[str] = None
    ) -> Dict:
        """
        Generate business insights.
        
        Analyzes trends and provides recommendations.
        """
        try:
            # Parse time range
            days = {
                "1d": 1,
                "7d": 7,
                "30d": 30,
                "90d": 90
            }.get(time_range, 7)
            
            async with AsyncSessionLocal() as session:
                if metric == "orders":
                    # Get order metrics
                    query = text("""
                        SELECT COUNT(*) as total_orders,
                            COUNT(CASE WHEN "createdAt" >= NOW() - INTERVAL ':days days' THEN 1 END) as recent_orders,
                            COUNT(CASE WHEN "createdAt" >= NOW() - INTERVAL ':prev_days days' 
                                  AND "createdAt" < NOW() - INTERVAL ':days days' THEN 1 END) as prev_period_orders
                        FROM orders
                    """)
                    
                    result = await session.execute(
                        query,
                        {"days": days, "prev_days": days * 2}
                    )
                    data = result.fetchone()
                    
                    current_value = data[1] if data else 0
                    prev_value = data[2] if data else 0
                    
                    # Calculate trend
                    if prev_value > 0:
                        change_percent = ((current_value - prev_value) / prev_value) * 100
                    else:
                        change_percent = 0.0
                    
                    trend = "up" if change_percent > 5 else "down" if change_percent < -5 else "stable"
                    
                    # Generate insights
                    insights = []
                    if trend == "up":
                        insights.append({
                            "type": "positive",
                            "message": f"Orders increased by {abs(change_percent):.1f}%"
                        })
                    elif trend == "down":
                        insights.append({
                            "type": "warning",
                            "message": f"Orders decreased by {abs(change_percent):.1f}%"
                        })
                    
                    # Recommendations
                    recommendations = []
                    if trend == "down":
                        recommendations.extend([
                            "Launch promotional campaign",
                            "Send re-engagement notifications",
                            "Analyze customer feedback"
                        ])
                    elif trend == "up":
                        recommendations.extend([
                            "Ensure adequate rider capacity",
                            "Monitor service quality",
                            "Consider expanding service area"
                        ])
                    
                    return {
                        "current_value": float(current_value),
                        "trend": trend,
                        "change_percent": round(change_percent, 1),
                        "insights": insights,
                        "recommendations": recommendations
                    }
                
                # Add more metrics as needed
                return {
                    "current_value": 0.0,
                    "trend": "stable",
                    "change_percent": 0.0,
                    "insights": [],
                    "recommendations": []
                }
                
        except Exception as e:
            self.logger.error("Insights generation failed", error=str(e))
            return {
                "current_value": 0.0,
                "trend": "unknown",
                "change_percent": 0.0,
                "insights": [],
                "recommendations": []
            }
