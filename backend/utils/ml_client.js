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
    timeout: 5000 // 5 second timeout for ML calls
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
        console.error(`🤖 ML Service Error (Recommendations): ${error.message} (Status: ${status})`);
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
    analyzeSentiment: exports.analyzeSentiment
};
