const User = require('../models/User');
const Order = require('../models/Order');
const { sendToUser } = require('./fcm_service');
const { createNotification } = require('./notification_service');

/**
 * Reorder Suggestion Service
 * 
 * Logic to suggest items users order frequently
 */

/**
 * Find users eligible for a reorder suggestion
 * @returns {Promise<Array>} List of eligible users
 */
const findEligibleUsers = async () => {
    try {
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        const now = new Date();

        return await User.find({
            'notificationSettings.reorderSuggestions': true,
            $or: [
                { lastReorderSuggestionAt: null },
                { lastReorderSuggestionAt: { $lt: sevenDaysAgo } }
            ],
            $or: [
                { reorderSuggestionsThisWeek: 0 },
                { reorderSuggestionsThisWeek: { $exists: false } }
            ]
        }).select('_id email username reorderSuggestionsThisWeek lastReorderSuggestionAt weekStartDate');
    } catch (error) {
        console.error('Error finding users for reorder suggestion:', error.message);
        return [];
    }
};

/**
 * Identify the best item to suggest for reordering
 * @param {ObjectId} userId - User ID
 * @returns {Promise<Object|null>} Best item or null
 */
const getFrequentItemToSuggest = async (userId) => {
    try {
        const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        const fiveDaysAgo = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000);

        // Get delivered orders from the last 30 days
        const orders = await Order.find({
            customer: userId,
            status: 'delivered',
            orderDate: { $gt: thirtyDaysAgo }
        });

        if (orders.length === 0) return null;

        // Map items to frequencies
        const itemFreq = new Map();
        const lastOrderedAt = new Map();

        orders.forEach(order => {
            order.items.forEach(item => {
                const itemId = (item.food || item.groceryItem)?.toString();
                if (!itemId) return;

                const currentCount = itemFreq.get(itemId) || 0;
                itemFreq.set(itemId, currentCount + 1);

                const currentLastDate = lastOrderedAt.get(itemId);
                if (!currentLastDate || order.orderDate > currentLastDate) {
                    lastOrderedAt.set(itemId, order.orderDate);
                }
            });
        });

        // Filter items: 3+ times in 30 days, NOT in the last 5 days
        const candidates = Array.from(itemFreq.entries())
            .filter(([id, count]) => count >= 3 && lastOrderedAt.get(id) < fiveDaysAgo)
            .sort((a, b) => b[1] - a[1]); // Most frequent first

        if (candidates.length === 0) return null;

        // Pick the top candidate
        const bestItemId = candidates[0][0];

        // Find the item details from the orders list (to avoid extra queries)
        let bestItemData = null;
        for (const order of orders) {
            const found = order.items.find(i => (i.food || i.groceryItem)?.toString() === bestItemId);
            if (found) {
                bestItemData = found;
                break;
            }
        }

        return bestItemData;
    } catch (error) {
        console.error(`Error getting frequent item for ${userId}:`, error.message);
        return null;
    }
};

/**
 * Send a reorder suggestion to a user
 * @param {Object} user - User object
 */
const sendReorderSuggestion = async (user) => {
    try {
        const item = await getFrequentItemToSuggest(user._id);
        if (!item) return;

        const templates = [
            {
                title: `🍴 Missing your ${item.name}?`,
                message: `Use code REORDER10 for 10% off your next order!`
            },
            {
                title: `🏠 Time to stock up?`,
                message: `Get ${item.name} with 10% off using code REORDER10!`
            },
            {
                title: `✨ Treat yourself to ${item.name}!`,
                message: `The usual? Save 10% with code REORDER10!`
            }
        ];

        const template = templates[Math.floor(Math.random() * templates.length)];

        // 1. In-app notification
        await createNotification(
            user._id,
            'reorder_suggestion',
            template.title,
            template.message,
            {
                itemId: (item.food || item.groceryItem).toString(),
                itemType: item.itemType,
                itemName: item.name,
                route: '/browse'
            }
        );

        // 2. Push notification
        await sendToUser(
            user._id,
            {
                title: template.title,
                body: template.message
            },
            {
                type: 'reorder_suggestion',
                itemId: (item.food || item.groceryItem).toString(),
                itemType: String(item.itemType),
                promoCode: 'REORDER10',
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
        );

        // 3. Update tracking
        const now = new Date();
        let weekStartDate = user.weekStartDate || now;

        // Reset weekly counters if week expired
        if (user.weekStartDate && now - user.weekStartDate > 7 * 24 * 60 * 60 * 1000) {
            weekStartDate = now;
        }

        await User.findByIdAndUpdate(user._id, {
            lastReorderSuggestionAt: now,
            reorderSuggestionsThisWeek: 1, // Max 1 per week for this specific type
            weekStartDate
        });

        console.log(`✅ Sent reorder suggestion (${item.name}) to ${user.email}`);

    } catch (error) {
        console.error(`Error sending reorder suggestion to ${user._id}:`, error.message);
    }
};

/**
 * Process all reorder suggestions
 */
const processReorderSuggestions = async () => {
    try {
        const users = await findEligibleUsers();
        console.log(`🔍 Found ${users.length} potentially eligible users for reorder prompts`);

        for (const user of users) {
            await new Promise(resolve => setTimeout(resolve, 500));
            await sendReorderSuggestion(user);
        }

        console.log(`📊 Reorder prompts processing complete`);
    } catch (error) {
        console.error('Error processing reorder suggestions:', error.message);
    }
};

module.exports = {
    processReorderSuggestions,
    getFrequentItemToSuggest,
    sendReorderSuggestion
};
