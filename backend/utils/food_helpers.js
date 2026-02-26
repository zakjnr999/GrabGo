const { isRestaurantOpen } = require('./restaurant');
const { calculateDistance, estimateDeliveryTime } = require('./distance');
const { normalizeRatingResponse } = require('./rating_calculator');

/**
 * Shared inclusion relations for food items across all endpoints
 */
const FOOD_INCLUDE_RELATIONS = {
    category: { select: { id: true, name: true } },
    restaurant: {
        select: {
            id: true,
            restaurantName: true,
            logo: true,
            rating: true,
            ratingCount: true,
            address: true,
            city: true,
            isOpen: true,
            averageDeliveryTime: true,
            averagePreparationTime: true,
            latitude: true,
            longitude: true,
            openingHours: {
                select: {
                    dayOfWeek: true,
                    openTime: true,
                    closeTime: true,
                    isClosed: true
                }
            }
        }
    }
};

/**
 * Helper to add aliases and calculate dynamic restaurant status/delivery time
 * @param {Array} foods - List of food items from Prisma
 * @param {string|number} userLat - User latitude
 * @param {string|number} userLng - User longitude
 */
const formatFoodResponse = (foods, userLat, userLng) => {
    if (!foods) return [];

    const userLatitude = userLat ? parseFloat(userLat) : null;
    const userLongitude = userLng ? parseFloat(userLng) : null;
    const validUserLocation = userLatitude !== null && userLongitude !== null && !isNaN(userLatitude) && !isNaN(userLongitude);

    return foods.map(food => {
        if (!food) return null;

        // 1. Calculate Delivery Time
        const prepTime = food.prepTimeMinutes > 0 ? food.prepTimeMinutes : (food.restaurant?.averagePreparationTime || 15);
        let minTime = null;
        let maxTime = null;

        if (validUserLocation && food.restaurant?.latitude && food.restaurant?.longitude) {
            const distanceKm = calculateDistance(
                food.restaurant.latitude,
                food.restaurant.longitude,
                userLatitude,
                userLongitude
            );
            const travelMinutes = estimateDeliveryTime(distanceKm);
            minTime = prepTime + travelMinutes;
            maxTime = minTime + 10;
        } else if (food.restaurant?.averageDeliveryTime) {
            // averageDeliveryTime is full ETA (order placed → delivered)
            minTime = food.restaurant.averageDeliveryTime;
            maxTime = minTime + 10;
        } else {
            const fallbackTravelMinutes = 25;
            minTime = prepTime + fallbackTravelMinutes;
            maxTime = minTime + 10;
        }

        // 2. Format Response
        const foodRatingMeta = normalizeRatingResponse({
            rating: food.rating,
            totalReviews: food.totalReviews,
        });
        const restaurantRatingMeta = normalizeRatingResponse({
            rating: food.restaurant?.rating,
            ratingCount: food.restaurant?.ratingCount,
        });

        return {
            ...food,
            rating: foodRatingMeta.rating,
            rawRating: foodRatingMeta.rawRating,
            weightedRating: foodRatingMeta.weightedRating,
            reviewCount: foodRatingMeta.reviewCount,
            totalReviews: foodRatingMeta.totalReviews,
            food_image: food.foodImage, // backward compatibility
            image: food.foodImage,      // backward compatibility
            isRestaurantOpen: isRestaurantOpen(food.restaurant),
            estimatedDeliveryTime: `${minTime}-${maxTime} min`,
            restaurant: {
                ...food.restaurant,
                rating: restaurantRatingMeta.rating,
                rawRating: restaurantRatingMeta.rawRating,
                weightedRating: restaurantRatingMeta.weightedRating,
                ratingCount: restaurantRatingMeta.ratingCount,
                totalReviews: restaurantRatingMeta.totalReviews,
                restaurant_name: food.restaurant?.restaurantName, // backward compatibility
                image: food.restaurant?.logo                       // backward compatibility
            }
        };
    }).filter(f => !!f);
};

module.exports = {
    FOOD_INCLUDE_RELATIONS,
    formatFoodResponse
};
