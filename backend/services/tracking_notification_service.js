const fcmService = require('./fcm_service');

class TrackingNotificationService {
    /**
     * Send tracking-related push notification
     * This is a wrapper around the existing FCM service
     */
    async sendTrackingNotification(userId, title, body, data = {}) {
        try {
            return await fcmService.sendToUser(
                userId,
                { title, body },
                {
                    type: 'tracking_update',
                    ...data
                }
            );
        } catch (error) {
            console.error('Error sending tracking notification:', error);
        }
    }

    /**
     * Send notifications based on tracking events
     * Uses existing FCM service functions
     */
    async handleTrackingEvent(tracking, eventType, orderNumber = null) {
        const orderId = tracking.orderId.toString();
        const customerId = tracking.customerId.toString();
        const orderNum = orderNumber || orderId.slice(-6);

        try {
            switch (eventType) {
                case 'rider_assigned':
                    await fcmService.sendOrderNotification(
                        customerId,
                        orderId,
                        orderNum,
                        'confirmed',
                        `${tracking.riderName || 'Your rider'} will deliver your order`
                    );
                    break;

                case 'rider_at_restaurant':
                    await fcmService.sendOrderNotification(
                        customerId,
                        orderId,
                        orderNum,
                        'preparing',
                        'Your rider is picking up your order'
                    );
                    break;

                case 'order_picked_up':
                    await fcmService.sendOrderNotification(
                        customerId,
                        orderId,
                        orderNum,
                        'picked_up',
                        'Your order is on the way!'
                    );
                    break;

                case 'rider_nearby':
                    await fcmService.sendDeliveryArrivingNotification(
                        customerId,
                        orderId,
                        orderNum,
                        2 // 2 minutes
                    );
                    break;

                case 'order_delivered':
                    await fcmService.sendOrderNotification(
                        customerId,
                        orderId,
                        orderNum,
                        'delivered',
                        'Enjoy your meal! 🎉'
                    );
                    break;

                default:
                    console.warn(`Unknown tracking event type: ${eventType}`);
            }
        } catch (error) {
            console.error(`Error handling tracking event ${eventType}:`, error);
        }
    }
}

module.exports = new TrackingNotificationService();