"""
Prediction API endpoints.
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.config import settings
from app.core.logging import get_logger
from app.core.security import get_api_key
from app.db import redis
from app.services.prediction_service import PredictionService

logger = get_logger(__name__)
router = APIRouter()


# Request/Response Models
class LocationData(BaseModel):
    """Location data."""
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: Optional[str] = None


class DeliveryTimeRequest(BaseModel):
    """Request for delivery time prediction."""
    order_id: Optional[str] = None
    restaurant_location: LocationData
    delivery_location: LocationData
    rider_id: Optional[str] = None
    preparation_time: Optional[int] = Field(15, description="Restaurant prep time in minutes")
    order_items_count: Optional[int] = Field(1, description="Number of items")


class DeliveryTimeResponse(BaseModel):
    """Delivery time prediction response."""
    success: bool = True
    message: str = "Delivery time predicted successfully"
    estimated_minutes: int
    estimated_arrival: str
    confidence: float
    factors: dict


class DemandForecastRequest(BaseModel):
    """Request for demand forecasting."""
    location: Optional[LocationData] = None
    service_type: str = Field("food", description="Service type: food, grocery, pharmacy")
    forecast_hours: int = Field(24, ge=1, le=168, description="Hours to forecast")
    granularity: str = Field("hourly", description="Granularity: hourly, daily")


class DemandForecastResponse(BaseModel):
    """Demand forecast response."""
    success: bool = True
    message: str = "Demand forecast generated successfully"
    forecasts: list
    peak_hours: list
    recommendations: dict


class ChurnPredictionRequest(BaseModel):
    """Request for churn prediction."""
    user_id: str


class ChurnPredictionResponse(BaseModel):
    """Churn prediction response."""
    success: bool = True
    message: str = "Churn risk assessed successfully"
    user_id: str
    churn_risk: float
    risk_level: str
    factors: dict
    recommendations: list


@router.post("/delivery-time", response_model=DeliveryTimeResponse)
async def predict_delivery_time(
    request: DeliveryTimeRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Predict accurate delivery time using ML.
    
    Factors considered:
    - Distance between locations
    - Current traffic conditions
    - Weather conditions
    - Restaurant preparation time
    - Rider performance history
    - Time of day
    - Historical delivery times for similar routes
    """
    try:
        # Check cache for similar predictions
        cache_key = None
        if request.order_id:
            cache_key = f"pred:eta:{request.order_id}"
            cached_result = await redis.get_cached(cache_key)
            if cached_result:
                logger.info("Returning cached ETA", order_id=request.order_id)
                return DeliveryTimeResponse(**cached_result)
        
        # Predict delivery time
        service = PredictionService()
        prediction = await service.predict_delivery_time(
            restaurant_location=(
                request.restaurant_location.latitude,
                request.restaurant_location.longitude
            ),
            delivery_location=(
                request.delivery_location.latitude,
                request.delivery_location.longitude
            ),
            rider_id=request.rider_id,
            preparation_time=request.preparation_time,
            order_items_count=request.order_items_count
        )
        
        # Calculate estimated arrival time
        estimated_arrival = datetime.utcnow()
        from datetime import timedelta
        estimated_arrival += timedelta(minutes=prediction["estimated_minutes"])
        
        response = DeliveryTimeResponse(
            estimated_minutes=prediction["estimated_minutes"],
            estimated_arrival=estimated_arrival.isoformat(),
            confidence=prediction["confidence"],
            factors=prediction["factors"]
        )
        
        # Cache result
        if cache_key:
            await redis.set_cached(
                cache_key,
                response.dict(),
                ttl=settings.PREDICTION_CACHE_TTL
            )
        
        logger.info(
            "Predicted delivery time",
            order_id=request.order_id,
            minutes=prediction["estimated_minutes"]
        )
        
        return response
        
    except Exception as e:
        logger.error("Delivery time prediction failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to predict delivery time: {str(e)}"
        )


@router.post("/demand", response_model=DemandForecastResponse)
async def forecast_demand(
    request: DemandForecastRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Forecast demand for the next hours/days.
    
    Useful for:
    - Restaurant capacity planning
    - Rider scheduling
    - Dynamic pricing
    - Inventory management
    """
    try:
        # Generate cache key
        location_key = "all"
        if request.location:
            location_key = f"{request.location.latitude:.2f},{request.location.longitude:.2f}"
        
        cache_key = f"pred:demand:{request.service_type}:{location_key}:{request.forecast_hours}"
        
        cached_result = await redis.get_cached(cache_key)
        if cached_result:
            logger.info("Returning cached demand forecast")
            return DemandForecastResponse(**cached_result)
        
        # Forecast demand
        service = PredictionService()
        forecast = await service.forecast_demand(
            service_type=request.service_type,
            location=(
                request.location.latitude,
                request.location.longitude
            ) if request.location else None,
            forecast_hours=request.forecast_hours,
            granularity=request.granularity
        )
        
        response = DemandForecastResponse(
            forecasts=forecast["forecasts"],
            peak_hours=forecast["peak_hours"],
            recommendations=forecast["recommendations"]
        )
        
        # Cache result (shorter TTL for demand forecasts)
        await redis.set_cached(
            cache_key,
            response.dict(),
            ttl=300  # 5 minutes
        )
        
        logger.info(
            "Generated demand forecast",
            service_type=request.service_type,
            hours=request.forecast_hours
        )
        
        return response
        
    except Exception as e:
        logger.error("Demand forecast failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to forecast demand: {str(e)}"
        )


@router.post("/churn", response_model=ChurnPredictionResponse)
async def predict_churn(
    request: ChurnPredictionRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Predict customer churn risk.
    
    Analyzes:
    - Order frequency decline
    - Time since last order
    - Customer engagement metrics
    - Support interactions
    - App usage patterns
    
    Returns risk level and retention recommendations.
    """
    try:
        # Check cache
        cache_key = f"pred:churn:{request.user_id}"
        
        cached_result = await redis.get_cached(cache_key)
        if cached_result:
            logger.info("Returning cached churn prediction", user_id=request.user_id)
            return ChurnPredictionResponse(**cached_result)
        
        # Predict churn
        service = PredictionService()
        prediction = await service.predict_churn(user_id=request.user_id)
        
        # Determine risk level
        risk_level = "low"
        if prediction["churn_risk"] >= settings.CHURN_THRESHOLD:
            risk_level = "high"
        elif prediction["churn_risk"] >= 0.4:
            risk_level = "medium"
        
        response = ChurnPredictionResponse(
            user_id=request.user_id,
            churn_risk=prediction["churn_risk"],
            risk_level=risk_level,
            factors=prediction["factors"],
            recommendations=prediction["recommendations"]
        )
        
        # Cache result
        await redis.set_cached(
            cache_key,
            response.dict(),
            ttl=3600  # 1 hour
        )
        
        logger.info(
            "Predicted churn risk",
            user_id=request.user_id,
            risk=prediction["churn_risk"],
            level=risk_level
        )
        
        return response
        
    except Exception as e:
        logger.error("Churn prediction failed", user_id=request.user_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to predict churn: {str(e)}"
        )
