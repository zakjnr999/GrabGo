const cron = require('node-cron');
const { findAbandonedCarts } = require('../services/cart_service');
const { createNotification } = require('../services/notification_service');
const cache = require('../utils/cache');

let isProcessing = false;

const processAbandonedCarts = async (io = null) => {
    if (isProcessing) {
        console.log('⏭️ Cart abandonment check already in progress, skipping...');
        return { processed: 0, notified: 0, failed: 0 };
    }

    isProcessing = true;
    const startTime = Date.now();

    try {
        console.log('🛒 Checking for abandoned carts...');

        const abandonedCarts = await findAbandonedCarts();

        if (abandonedCarts.length === 0) {
            console.log('✅ No abandoned carts found');
            return { processed: 0, notified: 0, failed: 0 };
        }

        console.log(`📦 Found ${abandonedCarts.length} abandoned cart(s)`);

        let notified = 0;
        let failed = 0;

        for (const cart of abandonedCarts) {
            try {
                if (cart.user.notificationSettings?.cartReminders === false) {
                    console.log(`⏭️ Skipping user ${cart.user.email} - cart reminders disabled`);
                    continue;
                }

                const itemCount = cart.itemCount;
                const totalAmount = cart.totalAmount.toFixed(2);
                const firstItemName = cart.items && cart.items.length > 0 && cart.items[0].name
                    ? cart.items[0].name
                    : 'items';

                await createNotification(
                    cart.user.id,
                    'cart_reminder',
                    '🛒 You left items in your cart',
                    `${firstItemName}${itemCount > 1 ? ` and ${itemCount - 1} more item${itemCount > 2 ? 's' : ''}` : ''} - Complete your order now!`,
                    {
                        cartId: cart.id,
                        itemCount: itemCount.toString(),
                        totalAmount: totalAmount,
                        route: '/cart'
                    },
                    io
                );

                const { markAbandonmentNotificationSent } = require('../services/cart_service');
                await markAbandonmentNotificationSent(cart.id);

                console.log(`✅ Sent cart reminder to ${cart.user.email}`);
                notified++;

            } catch (error) {
                console.error(`❌ Failed to send cart reminder to ${cart.user.email}:`, error.message);
                failed++;
            }
        }

        const duration = ((Date.now() - startTime) / 1000).toFixed(2);
        console.log(`📊 Cart abandonment check complete: ${notified} notified, ${failed} failed (${duration}s)`);

        return {
            processed: abandonedCarts.length,
            notified,
            failed
        };

    } catch (error) {
        console.error('❌ Error processing abandoned carts:', error.message);
        return { processed: 0, notified: 0, failed: 0 };
    } finally {
        isProcessing = false;
    }
};

const initializeCartAbandonmentJob = (io) => {
    console.log('📅 Initializing cart abandonment notification job...');

    cron.schedule('*/30 * * * *', async () => {
        const lock = await cache.acquireLock('job:cart_abandonment', 25 * 60);
        if (!lock) {
            console.log('⏭️ Cart abandonment skipped (lock held)');
            return;
        }
        try {
            await processAbandonedCarts(io);
        } finally {
            await cache.releaseLock(lock);
        }
    });

    console.log('✅ Cart abandonment job scheduled (runs every 30 minutes)');
};

module.exports = {
    initializeCartAbandonmentJob,
    processAbandonedCarts
};
