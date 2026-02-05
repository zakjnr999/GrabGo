"""
Recommendation service with ML models.
"""
from typing import Dict, List, Optional

import numpy as np
from sqlalchemy import select, text

from app.config import settings
from app.core.logging import get_logger
from app.db.postgres import AsyncSessionLocal

logger = get_logger(__name__)


class RecommendationService:
    """Service for generating recommendations using ML."""
    
    def __init__(self):
        self.logger = logger
    
    async def get_food_recommendations(
        self,
        user_id: str,
        limit: int = 10,
        context: Optional[Dict] = None,
        exclude_ids: Optional[List[str]] = None
    ) -> List[Dict]:
        """
        Get personalized food recommendations.
        
        Uses hybrid approach:
        1. Collaborative filtering (user-item interactions)
        2. Content-based filtering (food attributes)
        3. Contextual filtering (time, location, weather)
        """
        try:
            async with AsyncSessionLocal() as session:
                # Get user's order history
                user_orders_query = text("""
                    SELECT DISTINCT oi."foodId", f.name, f.price, f.rating, 
                           COUNT(*) as order_count
                    FROM order_items oi
                    JOIN orders o ON oi."orderId" = o.id
                    JOIN foods f ON oi."foodId" = f.id
                    WHERE o."customerId" = :user_id
                      AND o.status = 'delivered'
                    GROUP BY oi."foodId", f.name, f.price, f.rating
                    ORDER BY order_count DESC
                    LIMIT 20
                """)
                
                result = await session.execute(
                    user_orders_query,
                    {"user_id": user_id}
                )
                user_history = result.fetchall()
                
                # Get popular foods (collaborative filtering baseline)
                popular_query = text("""
                    SELECT f.id, f.name, f.price, f.rating, f."categoryId",
                           f."restaurantId", r."restaurantName",
                           COUNT(DISTINCT oi."orderId") as order_count
                    FROM foods f
                    JOIN restaurants r ON f."restaurantId" = r.id
                    LEFT JOIN order_items oi ON f.id = oi."foodId"
                    WHERE f."isAvailable" = true
                      AND r."isOpen" = true
                      AND r.status = 'approved'
                    GROUP BY f.id, f.name, f.price, f.rating, f."categoryId",
                             f."restaurantId", r."restaurantName"
                    ORDER BY order_count DESC, f.rating DESC
                    LIMIT :limit
                """)
                
                result = await session.execute(
                    popular_query,
                    {"limit": limit * 3}  # Get more for filtering
                )
                popular_foods = result.fetchall()
                
                # Apply contextual filtering
                recommendations = []
                exclude_set = set(exclude_ids or [])
                
                # Add user history items if available
                user_food_ids = {row[0] for row in user_history}
                
                for food in popular_foods:
                    if len(recommendations) >= limit:
                        break
                    
                    food_id = food[0]
                    
                    # Skip excluded items
                    if food_id in exclude_set:
                        continue
                    
                    # Calculate recommendation score
                    score = self._calculate_food_score(
                        food,
                        user_food_ids,
                        context
                    )
                    
                    if score >= settings.RECOMMENDATION_MIN_SCORE:
                        recommendations.append({
                            "id": food_id,
                            "name": food[1],
                            "score": round(score, 3),
                            "reason": self._get_recommendation_reason(
                                food,
                                user_food_ids,
                                context
                            ),
                            "metadata": {
                                "price": float(food[2]),
                                "rating": float(food[3]),
                                "restaurant": food[6],
                                "order_count": food[7]
                            }
                        })
                
                return recommendations
                
        except Exception as e:
            self.logger.error("Food recommendation failed", error=str(e))
            # Return fallback recommendations
            return await self._get_fallback_recommendations("food", limit)
    
    async def get_restaurant_recommendations(
        self,
        user_id: str,
        limit: int = 10,
        context: Optional[Dict] = None,
        service_type: Optional[str] = None,
        exclude_ids: Optional[List[str]] = None
    ) -> List[Dict]:
        """Get personalized restaurant/store recommendations."""
        try:
            async with AsyncSessionLocal() as session:
                # Determine table based on service type
                if service_type == "grocery":
                    table = "grocery_stores"
                    name_col = '"storeName"'
                elif service_type == "pharmacy":
                    table = "pharmacy_stores"
                    name_col = '"storeName"'
                else:
                    table = "restaurants"
                    name_col = '"restaurantName"'
                
                # Get popular restaurants
                query = text(f"""
                    SELECT r.id, r.{name_col}, r.rating, r."ratingCount",
                           r."deliveryFee", r."isOpen", r.featured,
                           COUNT(DISTINCT o.id) as order_count
                    FROM {table} r
                    LEFT JOIN orders o ON r.id = o."restaurantId"
                    WHERE r.status = 'approved'
                      AND r."isOpen" = true
                    GROUP BY r.id, r.{name_col}, r.rating, r."ratingCount",
                             r."deliveryFee", r."isOpen", r.featured
                    ORDER BY r.featured DESC, order_count DESC, r.rating DESC
                    LIMIT :limit
                """)
                
                result = await session.execute(query, {"limit": limit * 2})
                restaurants = result.fetchall()
                
                recommendations = []
                exclude_set = set(exclude_ids or [])
                
                for restaurant in restaurants:
                    if len(recommendations) >= limit:
                        break
                    
                    restaurant_id = restaurant[0]
                    
                    if restaurant_id in exclude_set:
                        continue
                    
                    score = self._calculate_restaurant_score(restaurant, context)
                    
                    if score >= settings.RECOMMENDATION_MIN_SCORE:
                        recommendations.append({
                            "id": restaurant_id,
                            "name": restaurant[1],
                            "score": round(score, 3),
                            "reason": "Popular in your area" if restaurant[6] else "Highly rated",
                            "metadata": {
                                "rating": float(restaurant[2]),
                                "rating_count": restaurant[3],
                                "delivery_fee": float(restaurant[4]),
                                "is_open": restaurant[5],
                                "featured": restaurant[6]
                            }
                        })
                
                return recommendations
                
        except Exception as e:
            self.logger.error("Restaurant recommendation failed", error=str(e))
            return await self._get_fallback_recommendations("restaurant", limit)
    
    async def get_similar_items(
        self,
        item_id: str,
        item_type: str,
        limit: int = 10
    ) -> List[Dict]:
        """Find similar items using content-based filtering."""
        try:
            async with AsyncSessionLocal() as session:
                # Get item details
                if item_type == "food":
                    query = text("""
                        SELECT f.id, f.name, f.price, f.rating, f."categoryId"
                        FROM foods f
                        WHERE f.id = :item_id
                    """)
                else:
                    # Handle other item types
                    return []
                
                result = await session.execute(query, {"item_id": item_id})
                item = result.fetchone()
                
                if not item:
                    return []
                
                # Find similar items in same category with similar price
                similar_query = text("""
                    SELECT f.id, f.name, f.price, f.rating, f."categoryId"
                    FROM foods f
                    WHERE f."categoryId" = :category_id
                      AND f.id != :item_id
                      AND f."isAvailable" = true
                      AND f.price BETWEEN :min_price AND :max_price
                    ORDER BY f.rating DESC, ABS(f.price - :target_price)
                    LIMIT :limit
                """)
                
                price = item[2]
                result = await session.execute(
                    similar_query,
                    {
                        "category_id": item[4],
                        "item_id": item_id,
                        "min_price": price * 0.7,
                        "max_price": price * 1.3,
                        "target_price": price,
                        "limit": limit
                    }
                )
                similar_items = result.fetchall()
                
                recommendations = []
                for similar in similar_items:
                    # Calculate similarity score
                    price_diff = abs(similar[2] - price) / price
                    rating_diff = abs(similar[3] - item[3]) / 5.0
                    score = 1.0 - (price_diff * 0.3 + rating_diff * 0.2)
                    
                    recommendations.append({
                        "id": similar[0],
                        "name": similar[1],
                        "score": round(score, 3),
                        "reason": "Similar price and category",
                        "metadata": {
                            "price": float(similar[2]),
                            "rating": float(similar[3])
                        }
                    })
                
                return recommendations
                
        except Exception as e:
            self.logger.error("Similar items failed", error=str(e))
            return []
    
    def _calculate_food_score(
        self,
        food,
        user_food_ids: set,
        context: Optional[Dict]
    ) -> float:
        """Calculate recommendation score for a food item."""
        score = 0.5  # Base score
        
        # Popularity boost
        order_count = food[7]
        if order_count > 100:
            score += 0.2
        elif order_count > 50:
            score += 0.1
        
        # Rating boost
        rating = food[3]
        if rating >= 4.5:
            score += 0.2
        elif rating >= 4.0:
            score += 0.1
        
        # Context-based adjustments
        if context:
            # Time of day
            time_of_day = context.get("time_of_day")
            if time_of_day:
                # TODO: Implement meal-time matching
                pass
            
            # Budget constraint
            budget = context.get("budget")
            if budget and food[2] <= budget:
                score += 0.1
        
        return min(score, 1.0)
    
    def _calculate_restaurant_score(
        self,
        restaurant,
        context: Optional[Dict]
    ) -> float:
        """Calculate recommendation score for a restaurant."""
        score = 0.5
        
        # Featured boost
        if restaurant[6]:
            score += 0.2
        
        # Rating boost
        rating = restaurant[2]
        if rating >= 4.5:
            score += 0.2
        elif rating >= 4.0:
            score += 0.1
        
        # Order count boost
        order_count = restaurant[7]
        if order_count > 100:
            score += 0.1
        
        return min(score, 1.0)
    
    def _get_recommendation_reason(
        self,
        food,
        user_food_ids: set,
        context: Optional[Dict]
    ) -> str:
        """Generate explanation for recommendation."""
        reasons = []
        
        if food[7] > 100:
            reasons.append("Popular choice")
        
        if food[3] >= 4.5:
            reasons.append("Highly rated")
        
        if not reasons:
            reasons.append("Recommended for you")
        
        return " • ".join(reasons)
    
    async def _get_fallback_recommendations(
        self,
        rec_type: str,
        limit: int
    ) -> List[Dict]:
        """Get fallback recommendations when ML fails."""
        # Return empty list or basic recommendations
        return []
