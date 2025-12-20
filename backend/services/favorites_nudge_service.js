const User = require('../models/User');
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

        // Find users with favorites
        const users = await User.find({
            'favorites.restaurants.0': { $exists: true }, // Has at least one favorite
            'notificationSettings.promoNotifications': true,
            // Never ordered OR haven't ordered in 7 days
            $or: [
                { lastOrderDate: null },
                { lastOrderDate: { $exists: false } },
                { lastOrderDate: { $lt: sevenDaysAgo } }
            ],
            // Never nudged OR haven't been nudged in 3 days
            $and: [
                {
                    $or: [
                        { lastFavoritesNudgeAt: null },
                        { lastFavoritesNudgeAt: { $exists: false } },
                        { lastFavoritesNudgeAt: { $lt: threeDaysAgo } }
                    ]
                }
            ]
        })
            .select('_id username email favorites lastOrderDate favoritesNudgesThisWeek lastFavoritesNudgeAt weekStartDate')
            // Populate the restaurant name for personalization
            .populate('favorites.restaurants.restaurantId', 'restaurant_name');

        // Filter by weekly limit (max 2)
        const eligibleUsers = users.filter(user => {
            const maxPerWeek = 2;

            // Check if week has expired
            let currentWeekNudges = user.favoritesNudgesThisWeek || 0;
            if (user.weekStartDate && now - user.weekStartDate > 7 * 24 * 60 * 60 * 1000) {
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
 * @param {Object} user - User object with populated favorites
 * @returns {Object} { title, message, restaurantId }
 */
const generateFavoritesMessage = (user) => {
    const favorites = user.favorites.restaurants;
    if (!favorites || favorites.length === 0) return null;

    // Pick a random favorite restaurant
    const randomIndex = Math.floor(Math.random() * favorites.length);
    const fav = favorites[randomIndex];

    // Safety check for restaurant name
    const restaurantName = fav.restaurantId?.restaurant_name;

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
        restaurantId: (fav.restaurantId._id || fav.restaurantId).toString()
    };
};

/**
 * Send a favorites nudge to a specific user
 * @param {Object} user - User object
 */
const sendFavoritesNudge = async (user) => {
    try {
        const nudgeData = generateFavoritesMessage(user);
        if (!nudgeData) return;

        // 1. In-app notification
        await createNotification(
            user._id,
            'favorites_reminder',
            nudgeData.title,
            nudgeData.message,
            {
                restaurantId: nudgeData.restaurantId
            }
        );

        // 2. Push notification
        await sendToUser(
            user._id,
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
        let favorsNudgesThisWeek = (user.favoritesNudgesThisWeek || 0) + 1;

        // Reset if week expired
        if (user.weekStartDate && now - user.weekStartDate > 7 * 24 * 60 * 60 * 1000) {
            weekStartDate = now;
            favorsNudgesThisWeek = 1;
        }

        await User.findByIdAndUpdate(user._id, {
            lastFavoritesNudgeAt: now,
            favoritesNudgesThisWeek: favorsNudgesThisWeek,
            weekStartDate
        });

        console.log(`✅ Sent favorites nudge to ${user.email}`);

    } catch (error) {
        console.error(`Error sending favorites nudge to ${user._id}:`, error.message);
    }
};

/**
 * Process all favorites nudges
 */
const processFavoritesNudges = async () => {
    try {
        const users = await findEligibleUsers();

        for (const user of users) {
            // Add slight random delay to avoid pounding FCM
            await new Promise(resolve => setTimeout(resolve, 500));
            await sendFavoritesNudge(user);
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
