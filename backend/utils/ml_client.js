const axios = require('axios');

/**
 * Client for interacting with the GrabGo ML Service
 */
const mlClient = axios.create({
    baseURL: process.env.ML_SERVICE_URL || 'https://grabgo-ml-service.onrender.com',
    headers: {
        'X-API-Key': process.env.ML_API_KEY,
        'Content-Type': 'application/json'
    },
    timeout: 10000 // 10 second timeout for ML calls
});

/**
 * Predict delivery time factors (Prep time, Rider performance)
 */
exports.predictDeliveryFactors = async (data) => {
    if (!process.env.ML_API_KEY) {
        console.warn('🤖 ML Service: ML_API_KEY is missing, skipping prediction.');
        return null;
    }

    try {
        const response = await mlClient.post('/api/v1/predictions/delivery-time', {
            order_id: data.orderId || null,
            rider_id: data.riderId,
            restaurant_id: data.restaurantId,
            order_items_count: data.itemsCount || 1,
            restaurant_location: data.restaurantLocation,
            delivery_location: data.deliveryLocation
        });
        // Return the root fields like 'factors' or 'prediction'
        return response.data;
    } catch (error) {
        const status = error.response?.status;
        console.error(`🤖 ML Service Error (Delivery Prediction): ${error.message} (Status: ${status})`);
        return null;
    }
};

/**
 * Get food recommendations for a user
 */
exports.getFoodRecommendations = async (userId, limit = 10) => {
    if (!process.env.ML_API_KEY) {
        console.warn('🤖 ML Service: ML_API_KEY is missing, skipping recommendations.');
        return [];
    }

    if (!userId) {
        return [];
    }

    try {
        const response = await mlClient.post('/api/v1/recommendations/food', {
            user_id: userId,
            limit: Math.min(limit, 50) // ML Service cap
        });
        // SUCCESS: The ML service puts the array inside the .data property
        return response.data.data || [];
    } catch (error) {
        const status = error.response?.status;
        const details = error.response?.data?.detail || error.response?.data || error.message;
        console.error(`🤖 ML Service Error (Recommendations): (Status: ${status})`, details);
        return [];
    }
};

/**
 * Get store recommendations for a user (grocery, pharmacy, grabmart, food)
 */
exports.getStoreRecommendations = async (userId, serviceType = 'food', limit = 10) => {
    if (!process.env.ML_API_KEY) {
        console.warn('🤖 ML Service: ML_API_KEY is missing, skipping store recommendations.');
        return [];
    }

    if (!userId) {
        return [];
    }

    try {
        const response = await mlClient.post('/api/v1/recommendations/restaurants', {
            user_id: userId,
            service_type: serviceType,
            limit: Math.min(limit, 50)
        });

        return response.data.data || [];
    } catch (error) {
        const status = error.response?.status;
        const details = error.response?.data?.detail || error.response?.data || error.message;
        console.error(`🤖 ML Service Error (Store Recommendations): (Status: ${status})`, details);
        return [];
    }
};



/**
 * Analyze sentiment for a review or message
 */
exports.analyzeSentiment = async (text) => {
    try {
        const response = await mlClient.post('/api/v1/analytics/sentiment', {
            text: text
        });
        return response.data;
    } catch (error) {
        console.error('🤖 ML Service Error (Sentiment):', error.message);
        return null;
    }
};

module.exports = {
    predictDeliveryFactors: exports.predictDeliveryFactors,
    getFoodRecommendations: exports.getFoodRecommendations,
    getStoreRecommendations: exports.getStoreRecommendations,
    analyzeSentiment: exports.analyzeSentiment
};
