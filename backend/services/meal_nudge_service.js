const User = require('../models/User');
const Order = require('../models/Order');
const Restaurant = require('../models/Restaurant');
const Food = require('../models/Food');
const { createNotification } = require('./notification_service');

/**
 * Meal-Time Nudge Service
 * 
 * Sends personalized meal-time notifications to re-engage inactive users
 * during breakfast, lunch, and dinner times
 */

/**
 * Find users eligible for meal-time nudges
 * @param {string} mealType - 'breakfast', 'lunch', or 'dinner'
 * @returns {Promise<Array>} Array of eligible users
 */
const findEligibleUsers = async (mealType) => {
    const now = new Date();
    const threeDaysAgo = new Date(now - 3 * 24 * 60 * 60 * 1000);
    const oneDayAgo = new Date(now - 24 * 60 * 60 * 1000);

    try {
        const users = await User.find({
            // Must have ordered before (not new users)
            lastOrderDate: { $exists: true, $ne: null, $lt: threeDaysAgo },

            // Meal notifications enabled
            'mealTimePreferences.enabled': true,
            [`mealTimePreferences.${mealType}`]: true,

            // General promo notifications enabled (meal nudges are promotional)
            'notificationSettings.promoNotifications': true,

            // Frequency limits
            $or: [
                { lastMealNudgeAt: null },
                { lastMealNudgeAt: { $lt: oneDayAgo } }
            ],

        }).select('_id username email lastOrderDate mealTimePreferences mealNudgesThisWeek weekStartDate');

        // Filter by weekly limit in JavaScript (simpler than $expr)
        const eligibleUsers = users.filter(user => {
            const maxPerWeek = user.mealTimePreferences?.maxPerWeek || 3;
            return user.mealNudgesThisWeek < maxPerWeek;
        });

        console.log(`🔍 Found ${eligibleUsers.length} eligible users for ${mealType} nudge`);
        return eligibleUsers;

    } catch (error) {
        console.error(`Error finding eligible users for ${mealType}:`, error.message);
        return [];
    }
};

/**
 * Generate personalized message for meal nudge
 * @param {Object} user - User object
 * @param {string} mealType - 'breakfast', 'lunch', or 'dinner'
 * @returns {Promise<Object>} { title, message, data }
 */
const generatePersonalizedMessage = async (user, mealType) => {
    try {
        // Get user's last order to personalize
        const lastOrder = await Order.findOne({ customer: user._id })
            .sort({ createdAt: -1 })
            .populate('restaurant', 'restaurant_name')
            .populate('items.food', 'name');

        // Get popular food item
        const popularFood = await Food.findOne({ isAvailable: true })
            .sort({ orderCount: -1 })
            .select('name');

        // Message templates by meal type
        const templates = {
            breakfast: [
                {
                    title: '🌅 Good Morning!',
                    message: lastOrder?.restaurant?.restaurant_name
                        ? `Start your day with breakfast from ${lastOrder.restaurant.restaurant_name}!`
                        : 'Start your day right with a delicious breakfast!',
                },
                {
                    title: '☕ Rise and Shine!',
                    message: popularFood
                        ? `Craving ${popularFood.name}? Order breakfast now!`
                        : 'Time for breakfast! Order your favorite meal.',
                },
                {
                    title: '🥐 Breakfast Time!',
                    message: 'Fuel your morning with a tasty breakfast delivery!',
                }
            ],
            lunch: [
                {
                    title: '🍔 Lunch Break!',
                    message: lastOrder?.restaurant?.restaurant_name
                        ? `Hungry? Order lunch from ${lastOrder.restaurant.restaurant_name}!`
                        : 'Time for lunch! Get your favorite meal delivered.',
                },
                {
                    title: '🍕 Lunchtime!',
                    message: popularFood
                        ? `${popularFood.name} is calling! Order lunch now.`
                        : 'Satisfy your lunch cravings with quick delivery!',
                },
                {
                    title: '🌮 Hungry?',
                    message: 'Get lunch delivered in 30 minutes or less!',
                }
            ],
            dinner: [
                {
                    title: '🍝 Dinner Time!',
                    message: lastOrder?.restaurant?.restaurant_name
                        ? `End your day with dinner from ${lastOrder.restaurant.restaurant_name}!`
                        : 'Relax and enjoy dinner delivered to your door!',
                },
                {
                    title: '🍛 Dinner\'s Calling!',
                    message: popularFood
                        ? `Craving ${popularFood.name}? Order dinner now!`
                        : 'Treat yourself to a delicious dinner tonight!',
                },
                {
                    title: '🍗 Evening Cravings?',
                    message: 'Order your favorite dinner and enjoy!',
                }
            ]
        };

        // Randomly select a template
        const mealTemplates = templates[mealType] || templates.lunch;
        const template = mealTemplates[Math.floor(Math.random() * mealTemplates.length)];

        return {
            title: template.title,
            message: template.message,
            data: {
                mealType,
                lastRestaurantId: lastOrder?.restaurant?._id?.toString() || null,
                route: '/browse'
            }
        };

    } catch (error) {
        console.error(`Error generating message for ${user.email}:`, error.message);

        // Fallback message
        return {
            title: '🍽️ Meal Time!',
            message: 'Order your favorite meal now!',
            data: { mealType, route: '/browse' }
        };
    }
};

/**
 * Send meal nudge to a user
 * @param {Object} user - User object
 * @param {string} mealType - 'breakfast', 'lunch', or 'dinner'
 * @param {Object} io - Socket.io instance
 * @returns {Promise<boolean>} Success status
 */
const sendMealNudge = async (user, mealType, io = null) => {
    try {
        // Generate personalized message
        const { title, message, data } = await generatePersonalizedMessage(user, mealType);

        // Create notification
        await createNotification(
            user._id,
            `meal_nudge_${mealType}`,
            title,
            message,
            data,
            io
        );

        // Update user's nudge tracking
        const now = new Date();
        const weekStart = user.weekStartDate || now;
        const daysSinceWeekStart = Math.floor((now - weekStart) / (24 * 60 * 60 * 1000));

        // Reset weekly counter if it's a new week (Sunday)
        let mealNudgesThisWeek, weekStartDate;
        if (daysSinceWeekStart >= 7 || !user.weekStartDate) {
            mealNudgesThisWeek = 1;
            weekStartDate = now;
        } else {
            mealNudgesThisWeek = user.mealNudgesThisWeek + 1;
            weekStartDate = user.weekStartDate;
        }

        // Use direct update to avoid triggering pre-save hooks
        await User.findByIdAndUpdate(user._id, {
            lastMealNudgeAt: now,
            mealNudgesThisWeek,
            weekStartDate
        });

        console.log(`✅ Sent ${mealType} nudge to ${user.email}`);
        return true;

    } catch (error) {
        console.error(`❌ Failed to send ${mealType} nudge to ${user.email}:`, error.message);
        return false;
    }
};

/**
 * Process meal nudges for a specific meal type
 * @param {string} mealType - 'breakfast', 'lunch', or 'dinner'
 * @param {Object} io - Socket.io instance
 * @returns {Promise<Object>} Results { sent, failed }
 */
const processMealNudges = async (mealType, io = null) => {
    const startTime = Date.now();
    console.log(`\n🍽️ Processing ${mealType} nudges...`);

    try {
        const eligibleUsers = await findEligibleUsers(mealType);

        if (eligibleUsers.length === 0) {
            console.log(`✅ No eligible users for ${mealType} nudges`);
            return { sent: 0, failed: 0 };
        }

        let sent = 0;
        let failed = 0;

        for (const user of eligibleUsers) {
            const success = await sendMealNudge(user, mealType, io);
            if (success) {
                sent++;
            } else {
                failed++;
            }
        }

        const duration = ((Date.now() - startTime) / 1000).toFixed(2);
        console.log(`📊 ${mealType.toUpperCase()} nudges complete: ${sent} sent, ${failed} failed (${duration}s)\n`);

        return { sent, failed };

    } catch (error) {
        console.error(`❌ Error processing ${mealType} nudges:`, error.message);
        return { sent: 0, failed: 0 };
    }
};

/**
 * Reset weekly counters for all users (runs Sunday midnight)
 */
const resetWeeklyCounters = async () => {
    try {
        console.log('🔄 Resetting weekly meal nudge counters...');

        const result = await User.updateMany(
            { mealNudgesThisWeek: { $gt: 0 } },
            {
                $set: {
                    mealNudgesThisWeek: 0,
                    weekStartDate: new Date()
                }
            }
        );

        console.log(`✅ Reset counters for ${result.modifiedCount} users`);

    } catch (error) {
        console.error('❌ Error resetting weekly counters:', error.message);
    }
};

module.exports = {
    findEligibleUsers,
    generatePersonalizedMessage,
    sendMealNudge,
    processMealNudges,
    resetWeeklyCounters
};
