const prisma = require('../config/prisma');
const { createNotification } = require('./notification_service');
const { createScopedLogger } = require('../utils/logger');

const console = createScopedLogger('meal_nudge_service');

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
        const mealPrefField = mealType === 'breakfast' ? 'breakfast' : mealType === 'lunch' ? 'lunch' : 'dinner';

        const users = await prisma.user.findMany({
            where: {
                // Must have ordered before (not new users)
                lastOrderDate: { lt: threeDaysAgo },

                // Meal notifications enabled
                mealTimePreferences: {
                    enabled: true,
                    [mealPrefField]: true
                },

                // General promo notifications enabled
                notificationSettings: {
                    promoNotifications: true
                },

                // Frequency limits
                OR: [
                    { lastMealNudgeAt: null },
                    { lastMealNudgeAt: { lt: oneDayAgo } }
                ]
            },
            select: {
                id: true,
                username: true,
                email: true,
                lastOrderDate: true,
                mealNudgesThisWeek: true,
                weekStartDate: true,
                mealTimePreferences: {
                    select: {
                        maxPerWeek: true
                    }
                }
            }
        });

        // Filter by weekly limit in JavaScript
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
        const lastOrder = await prisma.order.findFirst({
            where: { customerId: user.id },
            orderBy: { createdAt: 'desc' },
            include: {
                restaurant: { select: { restaurantName: true } },
                items: {
                    where: { itemType: 'Food' },
                    take: 1
                }
            }
        });

        // Get popular food item
        const popularFood = await prisma.food.findFirst({
            where: { isAvailable: true },
            orderBy: { orderCount: 'desc' },
            select: { name: true }
        });

        // Message templates by meal type
        const templates = {
            breakfast: [
                {
                    title: '🌅 Good Morning!',
                    message: lastOrder?.restaurant?.restaurantName
                        ? `Start your day with breakfast from ${lastOrder.restaurant.restaurantName}!`
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
                    message: lastOrder?.restaurant?.restaurantName
                        ? `Hungry? Order lunch from ${lastOrder.restaurant.restaurantName}!`
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
                    message: lastOrder?.restaurant?.restaurantName
                        ? `End your day with dinner from ${lastOrder.restaurant.restaurantName}!`
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
                lastRestaurantId: lastOrder?.restaurantId || null,
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
            user.id,
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

        // Reset weekly counter if it's a new week (7+ days)
        let mealNudgesThisWeek, weekStartDate;
        if (daysSinceWeekStart >= 7 || !user.weekStartDate) {
            mealNudgesThisWeek = 1;
            weekStartDate = now;
        } else {
            mealNudgesThisWeek = (user.mealNudgesThisWeek || 0) + 1;
            weekStartDate = user.weekStartDate;
        }

        await prisma.user.update({
            where: { id: user.id },
            data: {
                lastMealNudgeAt: now,
                mealNudgesThisWeek,
                weekStartDate
            }
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

        const result = await prisma.user.updateMany({
            where: {
                OR: [
                    { mealNudgesThisWeek: { gt: 0 } },
                    { favoritesNudgesThisWeek: { gt: 0 } },
                    { reorderSuggestionsThisWeek: { gt: 0 } }
                ]
            },
            data: {
                mealNudgesThisWeek: 0,
                favoritesNudgesThisWeek: 0,
                reorderSuggestionsThisWeek: 0,
                weekStartDate: new Date()
            }
        });

        console.log(`✅ Reset counters for ${result.count} users`);

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
