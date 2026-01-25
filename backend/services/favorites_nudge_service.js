const prisma = require('../config/prisma');
const { sendToUser } = require('./fcm_service');
const { createNotification } = require('./notification_service');

/**
 * Favorites Nudge Service
 * 
 * Logic to remind users about their favorite restaurants
 */

/**
 * Find users eligible for a favorites nudge
 * Criteria:
 * - Has at least one favorite restaurant
 * - Haven't ordered in 7+ days (168 hours)
 * - Haven't received a favorites nudge in 3+ days (avoid spamming)
 * - Haven't hit weekly limit (max 2 per week)
 * - Promo/Engagement notifications enabled
 * 
 * @returns {Promise<Array>} List of eligible users
 */
const findEligibleUsers = async () => {
    try {
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
        const now = new Date();

        // Get users with favorites and specific notification settings
        const users = await prisma.user.findMany({
            where: {
                favoriteRestaurants: { some: {} }, // Has at least one favorite
                notificationSettings: { favoritesReminders: true },
                OR: [
                    { lastOrderDate: null },
                    { lastOrderDate: { lt: sevenDaysAgo } }
                ],
                OR: [
                    { lastFavoritesNudgeAt: null },
                    { lastFavoritesNudgeAt: { lt: threeDaysAgo } }
                ]
            },
            select: {
                id: true,
                username: true,
                email: true,
                lastOrderDate: true,
                favoritesNudgesThisWeek: true,
                lastFavoritesNudgeAt: true,
                weekStartDate: true,
                favoriteRestaurants: {
                    include: {
                        restaurant: {
                            select: {
                                id: true,
                                restaurantName: true
                            }
                        }
                    }
                }
            }
        });

        // Filter by weekly limit (max 2)
        const eligibleUsers = users.filter(user => {
            const maxPerWeek = 2;

            // Check if week has expired
            let currentWeekNudges = user.favoritesNudgesThisWeek || 0;
            if (user.weekStartDate && (now - user.weekStartDate) > 7 * 24 * 60 * 60 * 1000) {
                currentWeekNudges = 0;
            }

            return currentWeekNudges < maxPerWeek;
        });

        console.log(`🔍 Found ${eligibleUsers.length} eligible users for favorites nudge`);
        return eligibleUsers;

    } catch (error) {
        console.error('Error finding users for favorites nudge:', error.message);
        return [];
    }
};

/**
 * Generate a personalized message for a favorites nudge
 * @param {Object} user - User object with Prisma relations
 * @returns {Object} { title, message, restaurantId }
 */
const generateFavoritesMessage = (user) => {
    const favorites = user.favoriteRestaurants;
    if (!favorites || favorites.length === 0) return null;

    // Pick a random favorite restaurant
    const randomIndex = Math.floor(Math.random() * favorites.length);
    const fav = favorites[randomIndex];

    // Safety check for restaurant name
    const restaurantName = fav.restaurant?.restaurantName;

    let templates;
    if (restaurantName) {
        templates = [
            {
                title: `🍔 Missing ${restaurantName}?`,
                message: `Use code FAVE10 for 10% off your next order!`
            },
            {
                title: `🍕 ${restaurantName} is waiting!`,
                message: `Get 10% off with code FAVE10. Order now!`
            },
            {
                title: `✨ Craving ${restaurantName}?`,
                message: `Special offer: 10% off with FAVE10!`
            }
        ];
    } else {
        templates = [
            {
                title: '🍔 Missing your favorites?',
                message: 'Use code FAVE10 for 10% off your next order!'
            },
            {
                title: '🍕 Craving something good?',
                message: 'Get 10% off with code FAVE10!'
            },
            {
                title: '✨ Time for a treat?',
                message: 'Order from your favorites and save 10% with FAVE10!'
            }
        ];
    }

    const template = templates[Math.floor(Math.random() * templates.length)];

    return {
        ...template,
        restaurantId: fav.restaurantId
    };
};

/**
 * Send a favorites nudge to a specific user
 * @param {Object} user - User object
 * @param {Object} io - Socket.io instance
 */
const sendFavoritesNudge = async (user, io = null) => {
    try {
        const nudgeData = generateFavoritesMessage(user);
        if (!nudgeData) return;

        // 1. In-app notification
        await createNotification(
            user.id,
            'favorites_reminder',
            nudgeData.title,
            nudgeData.message,
            {
                restaurantId: nudgeData.restaurantId
            },
            io
        );

        // 2. Push notification
        await sendToUser(
            user.id,
            {
                title: nudgeData.title,
                body: nudgeData.message
            },
            {
                type: 'favorites_reminder',
                restaurantId: nudgeData.restaurantId,
                promoCode: 'FAVE10',
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
        );

        // 3. Update user tracking
        const now = new Date();
        let weekStartDate = user.weekStartDate || now;
        let favoritesNudgesThisWeek = (user.favoritesNudgesThisWeek || 0) + 1;

        // Reset if week expired
        if (user.weekStartDate && (now - user.weekStartDate) > 7 * 24 * 60 * 60 * 1000) {
            weekStartDate = now;
            favoritesNudgesThisWeek = 1;
        }

        await prisma.user.update({
            where: { id: user.id },
            data: {
                lastFavoritesNudgeAt: now,
                favoritesNudgesThisWeek: favoritesNudgesThisWeek,
                weekStartDate
            }
        });

        console.log(`✅ Sent favorites nudge to ${user.email}`);

    } catch (error) {
        console.error(`Error sending favorites nudge to ${user.id}:`, error.message);
    }
};

/**
 * Process all favorites nudges
 * @param {Object} io - Socket.io instance
 */
const processFavoritesNudges = async (io = null) => {
    try {
        const users = await findEligibleUsers();

        for (const user of users) {
            // Add slight random delay to avoid pounding FCM
            await new Promise(resolve => setTimeout(resolve, 500));
            await sendFavoritesNudge(user, io);
        }

        console.log(`📊 Favorites nudges processing complete: ${users.length} processed`);

    } catch (error) {
        console.error('Error processing favorites nudges:', error.message);
    }
};

module.exports = {
    processFavoritesNudges,
    findEligibleUsers,
    sendFavoritesNudge
};
