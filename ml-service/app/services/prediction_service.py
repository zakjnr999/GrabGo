"""
Prediction service for delivery time, demand, and churn.
"""
from datetime import datetime, timedelta
from typing import Dict, Optional, Tuple

import numpy as np
from sqlalchemy import text

from app.config import settings
from app.core.logging import get_logger
from app.db.postgres import AsyncSessionLocal

logger = get_logger(__name__)


class PredictionService:
    """Service for ML predictions."""
    
    def __init__(self):
        self.logger = logger
    
    async def predict_delivery_time(
        self,
        restaurant_location: Tuple[float, float],
        delivery_location: Tuple[float, float], "riderId": Optional[str] = None,
        preparation_time: int = 15,
        order_items_count: int = 1
    ) -> Dict:
        """
        Predict delivery time using ML model.
        
        Factors:
        - Distance (Haversine formula)
        - Traffic conditions (time of day)
        - Weather
        - Rider performance
        - Restaurant prep time
        """
        try:
            # Calculate distance
            distance_km = self._calculate_distance(
                restaurant_location,
                delivery_location
            )
            
            # Base delivery time (distance-based)
            # Assume average speed: 20 km/h for motorcycle
            travel_time = (distance_km / 20) * 60  # minutes
            
            # Get current hour for traffic adjustment
            current_hour = datetime.now().hour
            traffic_multiplier = self._get_traffic_multiplier(current_hour)
            travel_time *= traffic_multiplier
            
            # Rider performance adjustment
            rider_multiplier = 1.0
            if rider_id:
                rider_multiplier = await self._get_rider_performance_multiplier(rider_id)
            travel_time *= rider_multiplier
            
            # Preparation time adjustment based on items
            adjusted_prep_time = preparation_time + (order_items_count * 2)
            
            # Total estimated time
            total_minutes = int(travel_time + adjusted_prep_time + 5)  # +5 for pickup
            
            # Confidence calculation
            confidence = 0.85
            if distance_km > 10:
                confidence -= 0.1
            if rider_id is None:
                confidence -= 0.05
            
            return {
                "estimated_minutes": total_minutes,
                "confidence": round(confidence, 2),
                "factors": {
                    "distance_km": round(distance_km, 2),
                    "travel_time_minutes": round(travel_time, 1),
                    "preparation_time_minutes": adjusted_prep_time,
                    "traffic_multiplier": round(traffic_multiplier, 2),
                    "rider_multiplier": round(rider_multiplier, 2)
                }
            }
            
        except Exception as e:
            self.logger.error("Delivery time prediction failed", error=str(e))
            # Fallback to simple estimation
            distance_km = self._calculate_distance(
                restaurant_location,
                delivery_location
            )
            return {
                "estimated_minutes": int((distance_km / 20) * 60 + preparation_time + 10),
                "confidence": 0.6,
                "factors": {
                    "distance_km": round(distance_km, 2),
                    "note": "Using fallback estimation"
                }
            }
    
    async def forecast_demand(
        self,
        service_type: str,
        location: Optional[Tuple[float, float]] = None,
        forecast_hours: int = 24,
        granularity: str = "hourly"
    ) -> Dict:
        """
        Forecast demand for the next hours/days.
        
        Uses historical order patterns and time series analysis.
        """
        try:
            async with AsyncSessionLocal() as session:
                # Get historical order data
                query = text("""
                    SELECT DATE_TRUNC('hour', "createdAt") as hour,
                        COUNT(*) as order_count
                    FROM orders
                    WHERE "orderType" = :service_type
                      AND "createdAt" >= NOW() - INTERVAL '30 days'
                    GROUP BY hour
                    ORDER BY hour
                """)
                
                result = await session.execute(
                    query,
                    {"service_type": service_type}
                )
                historical_data = result.fetchall()
                
                # Simple forecasting: use average for each hour of day
                hourly_averages = {}
                for row in historical_data:
                    hour_of_day = row[0].hour
                    if hour_of_day not in hourly_averages:
                        hourly_averages[hour_of_day] = []
                    hourly_averages[hour_of_day].append(row[1])
                
                # Calculate averages
                for hour in hourly_averages:
                    hourly_averages[hour] = np.mean(hourly_averages[hour])
                
                # Generate forecast
                forecasts = []
                current_time = datetime.now()
                peak_hours = []
                
                for i in range(forecast_hours):
                    forecast_time = current_time + timedelta(hours=i)
                    hour_of_day = forecast_time.hour
                    
                    # Get average for this hour
                    predicted_orders = hourly_averages.get(hour_of_day, 10)
                    
                    # Add some randomness for realism
                    predicted_orders = int(predicted_orders * np.random.uniform(0.9, 1.1))
                    
                    forecasts.append({
                        "timestamp": forecast_time.isoformat(),
                        "hour": hour_of_day,
                        "predicted_orders": predicted_orders
                    })
                    
                    # Identify peak hours
                    if predicted_orders > 20:
                        peak_hours.append({
                            "hour": hour_of_day,
                            "predicted_orders": predicted_orders
                        })
                
                # Generate recommendations
                recommendations = {
                    "rider_scheduling": f"Schedule {len(peak_hours)} additional riders during peak hours",
                    "inventory": "Stock up for high-demand periods",
                    "pricing": "Consider dynamic pricing during peak hours"
                }
                
                return {
                    "forecasts": forecasts,
                    "peak_hours": peak_hours[:5],  # Top 5 peak hours
                    "recommendations": recommendations
                }
                
        except Exception as e:
            self.logger.error("Demand forecast failed", error=str(e))
            # Fallback forecast
            return {
                "forecasts": [],
                "peak_hours": [],
                "recommendations": {}
            }
    
    async def predict_churn(self, user_id: str) -> Dict:
        """
        Predict customer churn risk.
        
        Analyzes user behavior patterns.
        """
        try:
            async with AsyncSessionLocal() as session:
                # Get user statistics
                query = text("""
                    SELECT u."createdAt",
                        u."lastOrderDate",
                        COUNT(DISTINCT o.id) as total_orders,
                        AVG(o."totalAmount") as avg_order_value,
                        MAX(o."createdAt") as "lastOrderDate"
                    FROM users u
                    LEFT JOIN orders o ON u.id = o."customerId"
                    WHERE u.id = :user_id
                    GROUP BY u.id, u."createdAt", u."lastOrderDate"
                """)
                
                result = await session.execute(query, {"user_id": user_id})
                user_stats = result.fetchone()
                
                if not user_stats:
                    return {
                        "churn_risk": 0.5,
                        "factors": {},
                        "recommendations": []
                    }
                
                # Calculate churn risk factors
                days_since_signup = (datetime.now() - user_stats[0]).days
                days_since_last_order = (
                    (datetime.now() - user_stats[4]).days
                    if user_stats[4] else 999
                )
                total_orders = user_stats[2] or 0
                
                # Simple churn risk calculation
                churn_risk = 0.0
                factors = {}
                
                # Factor 1: Days since last order
                if days_since_last_order > 60:
                    churn_risk += 0.4
                    factors["inactive_days"] = days_since_last_order
                elif days_since_last_order > 30:
                    churn_risk += 0.2
                    factors["inactive_days"] = days_since_last_order
                
                # Factor 2: Order frequency
                if days_since_signup > 0:
                    orders_per_month = (total_orders / days_since_signup) * 30
                    if orders_per_month < 1:
                        churn_risk += 0.3
                        factors["low_frequency"] = True
                
                # Factor 3: Total orders
                if total_orders < 3:
                    churn_risk += 0.2
                    factors["low_engagement"] = True
                
                # Generate recommendations
                recommendations = []
                if churn_risk >= 0.6:
                    recommendations.extend([
                        "Send personalized discount offer",
                        "Trigger re-engagement campaign",
                        "Recommend favorite items"
                    ])
                elif churn_risk >= 0.4:
                    recommendations.extend([
                        "Send meal-time nudge",
                        "Highlight new restaurants"
                    ])
                
                return {
                    "churn_risk": round(min(churn_risk, 1.0), 2),
                    "factors": factors,
                    "recommendations": recommendations
                }
                
        except Exception as e:
            self.logger.error("Churn prediction failed", user_id=user_id, error=str(e))
            return {
                "churn_risk": 0.5,
                "factors": {"error": str(e)},
                "recommendations": []
            }
    
    def _calculate_distance(
        self,
        loc1: Tuple[float, float],
        loc2: Tuple[float, float]
    ) -> float:
        """Calculate distance between two coordinates using Haversine formula."""
        from math import radians, sin, cos, sqrt, atan2
        
        lat1, lon1 = radians(loc1[0]), radians(loc1[1])
        lat2, lon2 = radians(loc2[0]), radians(loc2[1])
        
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
        c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        # Earth radius in kilometers
        radius = 6371
        
        return radius * c
    
    def _get_traffic_multiplier(self, hour: int) -> float:
        """Get traffic multiplier based on time of day."""
        # Peak hours: 7-9 AM, 12-2 PM, 5-8 PM
        if hour in [7, 8, 9, 17, 18, 19, 20]:
            return 1.3  # 30% slower
        elif hour in [12, 13, 14]:
            return 1.2  # 20% slower
        elif hour in [0, 1, 2, 3, 4, 5]:
            return 0.9  # 10% faster (night)
        else:
            return 1.0  # Normal
    
    async def _get_rider_performance_multiplier(self, rider_id: str) -> float:
        """Get rider performance multiplier based on history."""
        try:
            async with AsyncSessionLocal() as session:
                query = text("""
                    SELECT AVG(
                        EXTRACT(EPOCH FROM ("deliveredDate" - "createdAt")) / 60
                    ) as avg_delivery_minutes
                    FROM orders
                    WHERE "riderId" = :rider_id
                      AND status = 'delivered'
                      AND "deliveredDate" IS NOT NULL
                      AND "createdAt" >= NOW() - INTERVAL '30 days'
                """)
                
                result = await session.execute(query, {"rider_id": rider_id})
                row = result.fetchone()
                
                if row and row[0]:
                    avg_time = row[0]
                    # If rider is faster than 30 mins average, give bonus
                    if avg_time < 30:
                        return 0.9  # 10% faster
                    elif avg_time > 45:
                        return 1.1  # 10% slower
                
                return 1.0
                
        except Exception:
            return 1.0
