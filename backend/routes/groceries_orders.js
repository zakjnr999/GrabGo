const express = require('express');
const router = express.Router();
const Order = require('../models/Order');
const GroceryItem = require('../models/GroceryItem');
const { protect } = require('../middleware/auth');

/**
 * @route   GET /api/groceries/order-history
 * @desc    Get grocery order history for current user
 * @access  Private
 */
router.get('/order-history', protect, async (req, res) => {
    try {
        // Get completed grocery orders for the current user
        const orders = await Order.find({
            customer: req.user._id,
            orderType: 'grocery',
            status: { $in: ['delivered', 'completed'] }
        })
            .populate({
                path: 'items.groceryItem',
                model: 'GroceryItem',
                populate: [
                    { path: 'category', model: 'GroceryCategory' },
                    { path: 'store', model: 'GroceryStore' }
                ]
            })
            .sort({ deliveredDate: -1, orderDate: -1 })
            .limit(50); // Limit to last 50 orders

        if (!orders || orders.length === 0) {
            return res.status(200).json({
                success: true,
                count: 0,
                data: []
            });
        }

        // Extract unique grocery items from orders
        const itemsMap = new Map();

        orders.forEach(order => {
            order.items.forEach(item => {
                if (item.itemType === 'grocery' && item.groceryItem) {
                    const itemId = item.groceryItem._id.toString();

                    if (!itemsMap.has(itemId)) {
                        itemsMap.set(itemId, {
                            item: item.groceryItem,
                            lastOrdered: order.deliveredDate || order.orderDate,
                            timesOrdered: 1,
                            totalQuantity: item.quantity
                        });
                    } else {
                        const existing = itemsMap.get(itemId);
                        existing.timesOrdered += 1;
                        existing.totalQuantity += item.quantity;
                        // Update last ordered if this order is more recent
                        const orderDate = order.deliveredDate || order.orderDate;
                        if (orderDate > existing.lastOrdered) {
                            existing.lastOrdered = orderDate;
                        }
                    }
                }
            });
        });

        // Convert map to array and sort by last ordered date
        const buyAgainItems = Array.from(itemsMap.values())
            .sort((a, b) => b.lastOrdered - a.lastOrdered)
            .slice(0, 20) // Return top 20 most recent items
            .map(({ item, lastOrdered, timesOrdered, totalQuantity }) => ({
                ...item.toObject(),
                lastOrdered,
                timesOrdered,
                totalQuantity
            }));

        res.status(200).json({
            success: true,
            count: buyAgainItems.length,
            data: buyAgainItems
        });

    } catch (error) {
        console.error('Error fetching grocery order history:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch order history',
            message: error.message
        });
    }
});

module.exports = router;
