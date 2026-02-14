"""
Recommendation API endpoints.
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.config import settings
from app.core.logging import get_logger
from app.core.security import get_api_key
from app.db import redis
from app.services.recommendation_service import RecommendationService

logger = get_logger(__name__)
router = APIRouter()


# Request/Response Models
class RecommendationContext(BaseModel):
    """Context for recommendations."""
    time_of_day: Optional[str] = Field(None, description="Time: breakfast, lunch, dinner, snack")
    location: Optional[dict] = Field(None, description="User location {lat, lon}")
    weather: Optional[str] = Field(None, description="Weather condition")
    budget: Optional[float] = Field(None, description="Budget constraint")


class FoodRecommendationRequest(BaseModel):
    """Request for food recommendations."""
    user_id: str = Field(..., description="User ID")
    limit: int = Field(10, ge=1, le=50, description="Number of recommendations")
    context: Optional[RecommendationContext] = None
    exclude_ids: Optional[List[str]] = Field(None, description="Food IDs to exclude")


class RestaurantRecommendationRequest(BaseModel):
    """Request for restaurant recommendations."""
    user_id: str = Field(..., description="User ID")
    limit: int = Field(10, ge=1, le=50, description="Number of recommendations")
    context: Optional[RecommendationContext] = None
    service_type: Optional[str] = Field(None, description="Service: food, grocery, pharmacy, grabmart")
    exclude_ids: Optional[List[str]] = Field(None, description="Restaurant IDs to exclude")


class SimilarItemsRequest(BaseModel):
    """Request for similar items."""
    item_id: str = Field(..., description="Item ID")
    item_type: str = Field(..., description="Item type: food, grocery, pharmacy")
    limit: int = Field(10, ge=1, le=50, description="Number of similar items")


class RecommendationItem(BaseModel):
    """Recommendation item."""
    id: str
    name: str
    score: float
    reason: Optional[str] = None
    metadata: Optional[dict] = None


class RecommendationResponse(BaseModel):
    """Recommendation response."""
    success: bool = True
    message: str = "Recommendations generated successfully"
    data: List[RecommendationItem]
    total: int
    algorithm: str
    cached: bool = False


@router.post("/food", response_model=RecommendationResponse)
async def get_food_recommendations(
    request: FoodRecommendationRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Get personalized food recommendations for a user.
    
    Uses hybrid recommendation algorithm combining:
    - Collaborative filtering (user-based and item-based)
    - Content-based filtering (food attributes)
    - Contextual factors (time, location, weather)
    """
    try:
        # Check cache
        cache_key = f"rec:food:{request.user_id}:{request.limit}"
        if request.context:
            cache_key += f":{request.context.time_of_day or 'any'}"
        
        cached_result = await redis.get_cached(cache_key)
        if cached_result and settings.ENABLE_RECOMMENDATIONS:
            logger.info("Returning cached food recommendations", user_id=request.user_id)
            cached_result['cached'] = True
            return RecommendationResponse(**cached_result)
        
        # Generate recommendations
        service = RecommendationService()
        recommendations = await service.get_food_recommendations(
            user_id=request.user_id,
            limit=request.limit,
            context=request.context.dict() if request.context else None,
            exclude_ids=request.exclude_ids or []
        )
        
        response = RecommendationResponse(
            data=recommendations,
            total=len(recommendations),
            algorithm="hybrid",
            cached=False
        )
        
        # Cache result
        await redis.set_cached(
            cache_key,
            response.dict(),
            ttl=settings.RECOMMENDATION_CACHE_TTL
        )
        
        logger.info(
            "Generated food recommendations",
            user_id=request.user_id,
            count=len(recommendations)
        )
        
        return response
        
    except Exception as e:
        logger.error("Food recommendation failed", user_id=request.user_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate recommendations: {str(e)}"
        )


@router.post("/restaurants", response_model=RecommendationResponse)
async def get_restaurant_recommendations(
    request: RestaurantRecommendationRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Get personalized restaurant/store recommendations.
    
    Considers:
    - User order history
    - Restaurant ratings and popularity
    - Distance from user
    - Operating hours
    - User preferences
    """
    try:
        # Check cache
        cache_key = f"rec:restaurant:{request.user_id}:{request.limit}:{request.service_type or 'all'}"
        
        cached_result = await redis.get_cached(cache_key)
        if cached_result and settings.ENABLE_RECOMMENDATIONS:
            logger.info("Returning cached restaurant recommendations", user_id=request.user_id)
            cached_result['cached'] = True
            return RecommendationResponse(**cached_result)
        
        # Generate recommendations
        service = RecommendationService()
        recommendations = await service.get_restaurant_recommendations(
            user_id=request.user_id,
            limit=request.limit,
            context=request.context.dict() if request.context else None,
            service_type=request.service_type,
            exclude_ids=request.exclude_ids or []
        )
        
        response = RecommendationResponse(
            data=recommendations,
            total=len(recommendations),
            algorithm="hybrid",
            cached=False
        )
        
        # Cache result
        await redis.set_cached(
            cache_key,
            response.dict(),
            ttl=settings.RECOMMENDATION_CACHE_TTL
        )
        
        logger.info(
            "Generated restaurant recommendations",
            user_id=request.user_id,
            count=len(recommendations)
        )
        
        return response
        
    except Exception as e:
        logger.error("Restaurant recommendation failed", user_id=request.user_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate recommendations: {str(e)}"
        )


@router.post("/similar-items", response_model=RecommendationResponse)
async def get_similar_items(
    request: SimilarItemsRequest,
    api_key: str = Depends(get_api_key)
):
    """
    Find similar items based on content similarity.
    
    Uses item features like:
    - Category
    - Price range
    - Ingredients/attributes
    - User ratings
    """
    try:
        # Check cache
        cache_key = f"rec:similar:{request.item_type}:{request.item_id}:{request.limit}"
        
        cached_result = await redis.get_cached(cache_key)
        if cached_result:
            logger.info("Returning cached similar items", item_id=request.item_id)
            cached_result['cached'] = True
            return RecommendationResponse(**cached_result)
        
        # Generate recommendations
        service = RecommendationService()
        recommendations = await service.get_similar_items(
            item_id=request.item_id,
            item_type=request.item_type,
            limit=request.limit
        )
        
        response = RecommendationResponse(
            data=recommendations,
            total=len(recommendations),
            algorithm="content-based",
            cached=False
        )
        
        # Cache result (longer TTL for similar items)
        await redis.set_cached(
            cache_key,
            response.dict(),
            ttl=settings.RECOMMENDATION_CACHE_TTL * 2
        )
        
        logger.info(
            "Generated similar items",
            item_id=request.item_id,
            count=len(recommendations)
        )
        
        return response
        
    except Exception as e:
        logger.error("Similar items failed", item_id=request.item_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to find similar items: {str(e)}"
        )


@router.delete("/cache/{user_id}")
async def clear_user_recommendations_cache(
    user_id: str,
    api_key: str = Depends(get_api_key)
):
    """
    Clear recommendation cache for a specific user.
    
    Useful when user preferences change significantly.
    """
    try:
        pattern = f"rec:*:{user_id}:*"
        count = await redis.clear_cache_pattern(pattern)
        
        logger.info("Cleared recommendation cache", user_id=user_id, count=count)
        
        return {
            "success": True,
            "message": f"Cleared {count} cached recommendations",
            "user_id": user_id
        }
        
    except Exception as e:
        logger.error("Cache clear failed", user_id=user_id, error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to clear cache: {str(e)}"
        )
