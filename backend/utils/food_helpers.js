const { isRestaurantOpen } = require('./restaurant');
const { calculateDistance, estimateDeliveryTime } = require('./distance');

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
        const prepTime = food.restaurant?.averagePreparationTime || 15;
        let deliveryTime = 25; // default fallback

        if (validUserLocation && food.restaurant?.latitude && food.restaurant?.longitude) {
            const distanceKm = calculateDistance(
                food.restaurant.latitude,
                food.restaurant.longitude,
                userLatitude,
                userLongitude
            );
            deliveryTime = estimateDeliveryTime(distanceKm);
        }

        const minTime = prepTime + deliveryTime;
        const maxTime = minTime + 10;

        // 2. Format Response
        return {
            ...food,
            food_image: food.foodImage, // backward compatibility
            image: food.foodImage,      // backward compatibility
            isRestaurantOpen: isRestaurantOpen(food.restaurant),
            estimatedDeliveryTime: `${minTime}-${maxTime} min`,
            restaurant: {
                ...food.restaurant,
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
