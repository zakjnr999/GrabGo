// """
// Integration examples for GrabGo Node.js backend.

// This file shows how to integrate the ML service with your existing backend.
// """

// ==================== Setup ====================

// 1. Install axios in your backend
// npm install axios

// 2. Create ML service client
const axios = require('axios');

const ML_SERVICE_URL = process.env.ML_SERVICE_URL || 'http://localhost:8000';
const ML_API_KEY = process.env.ML_API_KEY || 'your-api-key';

const mlClient = axios.create({
    baseURL: ML_SERVICE_URL,
    headers: {
        'X-API-Key': ML_API_KEY,
        'Content-Type': 'application/json'
    },
    timeout: 10000 // 10 seconds
});

// ==================== Recommendations ====================

/**
 * Get food recommendations for a user
 */
async function getFoodRecommendations(userId, limit = 10, context = {}) {
    try {
        const response = await mlClient.post('/api/v1/recommendations/food', {
            user_id: userId,
            limit,
            context: {
                time_of_day: context.timeOfDay || null,
                location: context.location || null,
                budget: context.budget || null
            },
            exclude_ids: context.excludeIds || []
        });

        return response.data;
    } catch (error) {
        console.error('ML recommendation failed:', error.message);
        // Fallback to your existing recommendation logic
        return { success: false, data: [] };
    }
}

/**
 * Get restaurant recommendations
 */
async function getRestaurantRecommendations(userId, serviceType = 'food', limit = 10) {
    try {
        const response = await mlClient.post('/api/v1/recommendations/restaurants', {
            user_id: userId,
            limit,
            service_type: serviceType
        });

        return response.data;
    } catch (error) {
        console.error('ML recommendation failed:', error.message);
        return { success: false, data: [] };
    }
}

/**
 * Get similar items (for "You might also like" section)
 */
async function getSimilarItems(itemId, itemType = 'food', limit = 10) {
    try {
        const response = await mlClient.post('/api/v1/recommendations/similar-items', {
            item_id: itemId,
            item_type: itemType,
            limit
        });

        return response.data;
    } catch (error) {
        console.error('ML similar items failed:', error.message);
        return { success: false, data: [] };
    }
}

// ==================== Predictions ====================

/**
 * Predict delivery time for an order
 */
async function predictDeliveryTime(orderData) {
    try {
        const response = await mlClient.post('/api/v1/predictions/delivery-time', {
            order_id: orderData.orderId,
            restaurant_location: {
                latitude: orderData.restaurantLat,
                longitude: orderData.restaurantLon
            },
            delivery_location: {
                latitude: orderData.deliveryLat,
                longitude: orderData.deliveryLon
            },
            rider_id: orderData.riderId || null,
            preparation_time: orderData.prepTime || 15,
            order_items_count: orderData.itemsCount || 1
        });

        return response.data;
    } catch (error) {
        console.error('ML ETA prediction failed:', error.message);
        // Fallback to simple calculation
        return {
            success: false,
            estimated_minutes: 30,
            confidence: 0.5
        };
    }
}

/**
 * Forecast demand for capacity planning
 */
async function forecastDemand(serviceType = 'food', hours = 24) {
    try {
        const response = await mlClient.post('/api/v1/predictions/demand', {
            service_type: serviceType,
            forecast_hours: hours,
            granularity: 'hourly'
        });

        return response.data;
    } catch (error) {
        console.error('ML demand forecast failed:', error.message);
        return { success: false, forecasts: [] };
    }
}

/**
 * Predict customer churn risk
 */
async function predictChurnRisk(userId) {
    try {
        const response = await mlClient.post('/api/v1/predictions/churn', {
            user_id: userId
        });

        return response.data;
    } catch (error) {
        console.error('ML churn prediction failed:', error.message);
        return { success: false, churn_risk: 0.5 };
    }
}

// ==================== Analytics ====================

/**
 * Analyze sentiment of a review or message
 */
async function analyzeSentiment(text, context = 'review') {
    try {
        const response = await mlClient.post('/api/v1/analytics/sentiment', {
            text,
            context
        });

        return response.data;
    } catch (error) {
        console.error('ML sentiment analysis failed:', error.message);
        return { success: false, sentiment: 'neutral' };
    }
}

/**
 * Check order for fraud
 */
async function checkFraud(userId, orderData) {
    try {
        const response = await mlClient.post('/api/v1/analytics/fraud-check', {
            user_id: userId,
            order_data: orderData
        });

        return response.data;
    } catch (error) {
        console.error('ML fraud check failed:', error.message);
        return { success: false, is_suspicious: false };
    }
}

/**
 * Get business insights
 */
async function getInsights(metric = 'orders', timeRange = '7d') {
    try {
        const response = await mlClient.post('/api/v1/analytics/insights', {
            metric,
            time_range: timeRange
        });

        return response.data;
    } catch (error) {
        console.error('ML insights failed:', error.message);
        return { success: false };
    }
}

// ==================== Integration Examples ====================

/**
 * Example 1: Enhance food listing endpoint with recommendations
 */
router.get('/api/foods/recommended', protect, async (req, res) => {
    try {
        const userId = req.user.id;

        // Get ML recommendations
        const mlRecommendations = await getFoodRecommendations(userId, 10, {
            timeOfDay: getCurrentMealTime(),
            location: req.query.location ? JSON.parse(req.query.location) : null
        });

        if (mlRecommendations.success && mlRecommendations.data.length > 0) {
            // Fetch full food details from database
            const foodIds = mlRecommendations.data.map(r => r.id);
            const foods = await prisma.food.findMany({
                where: { id: { in: foodIds } },
                include: { restaurant: true }
            });

            // Merge ML scores with food data
            const enrichedFoods = foods.map(food => {
                const mlData = mlRecommendations.data.find(r => r.id === food.id);
                return {
                    ...food,
                    recommendationScore: mlData?.score,
                    recommendationReason: mlData?.reason
                };
            });

            return res.json({
                success: true,
                data: enrichedFoods,
                algorithm: 'ml-powered'
            });
        }

        // Fallback to existing logic
        const foods = await prisma.food.findMany({
            where: { isAvailable: true },
            orderBy: { rating: 'desc' },
            take: 10
        });

        res.json({ success: true, data: foods });

    } catch (error) {
        console.error('Recommended foods error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

/**
 * Example 2: Enhance order creation with fraud detection
 */
router.post('/api/orders', protect, async (req, res) => {
    try {
        const userId = req.user.id;
        const orderData = req.body;

        // Check for fraud before creating order
        const fraudCheck = await checkFraud(userId, {
            total_amount: orderData.totalAmount,
            items_count: orderData.items.length,
            payment_method: orderData.paymentMethod,
            delivery_address: orderData.deliveryAddress
        });

        // If high risk, require additional verification
        if (fraudCheck.is_suspicious && fraudCheck.risk_score > 0.7) {
            return res.status(400).json({
                success: false,
                message: 'Additional verification required',
                requiresVerification: true,
                reason: 'Security check'
            });
        }

        // Create order (existing logic)
        const order = await prisma.order.create({
            data: {
                // ... your existing order creation logic
            }
        });

        // Predict delivery time
        const etaPrediction = await predictDeliveryTime({
            orderId: order.id,
            restaurantLat: order.restaurant.latitude,
            restaurantLon: order.restaurant.longitude,
            deliveryLat: orderData.deliveryAddress.latitude,
            deliveryLon: orderData.deliveryAddress.longitude,
            prepTime: order.restaurant.averagePreparationTime
        });

        // Update order with predicted ETA
        if (etaPrediction.success) {
            await prisma.order.update({
                where: { id: order.id },
                data: {
                    estimatedDeliveryMinutes: etaPrediction.estimated_minutes,
                    estimatedDeliveryTime: new Date(etaPrediction.estimated_arrival)
                }
            });
        }

        res.status(201).json({
            success: true,
            data: order,
            eta: etaPrediction
        });

    } catch (error) {
        console.error('Order creation error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

/**
 * Example 3: Analyze review sentiment
 */
router.post('/api/reviews', protect, async (req, res) => {
    try {
        const { orderId, rating, comment } = req.body;

        // Analyze sentiment if comment provided
        let sentiment = null;
        if (comment) {
            const sentimentAnalysis = await analyzeSentiment(comment, 'review');
            sentiment = sentimentAnalysis.sentiment;

            // If negative sentiment, flag for priority review
            if (sentiment === 'negative' && sentimentAnalysis.score < 0.3) {
                // Notify support team
                await notifySupportTeam({
                    type: 'negative_review',
                    orderId,
                    comment,
                    sentiment: sentimentAnalysis
                });
            }
        }

        // Create review
        const review = await prisma.review.create({
            data: {
                orderId,
                rating,
                comment,
                sentiment,
                userId: req.user.id
            }
        });

        res.status(201).json({ success: true, data: review });

    } catch (error) {
        console.error('Review creation error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

/**
 * Example 4: Churn prevention - identify at-risk users
 */
async function runChurnPreventionJob() {
    try {
        // Get users who haven't ordered in 30 days
        const inactiveUsers = await prisma.user.findMany({
            where: {
                lastOrderDate: {
                    lt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
                },
                role: 'customer'
            },
            take: 100
        });

        for (const user of inactiveUsers) {
            // Predict churn risk
            const churnPrediction = await predictChurnRisk(user.id);

            if (churnPrediction.risk_level === 'high') {
                // Send personalized re-engagement campaign
                await sendReengagementCampaign(user, {
                    recommendations: churnPrediction.recommendations,
                    personalizedOffer: true
                });

                console.log(`Sent re-engagement to user ${user.id} (churn risk: ${churnPrediction.churn_risk})`);
            }
        }

    } catch (error) {
        console.error('Churn prevention job error:', error);
    }
}

// Run churn prevention daily
const cron = require('node-cron');
cron.schedule('0 9 * * *', runChurnPreventionJob); // Daily at 9 AM

// ==================== Export ====================

module.exports = {
    getFoodRecommendations,
    getRestaurantRecommendations,
    getSimilarItems,
    predictDeliveryTime,
    forecastDemand,
    predictChurnRisk,
    analyzeSentiment,
    checkFraud,
    getInsights
};
