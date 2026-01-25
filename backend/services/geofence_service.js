const geolib = require('geolib');
const prisma = require('../config/prisma');
const socketService = require('./socket_service');

class GeofenceService {

    // Geofence radiuses in meters
    static PICKUP_RADIUS = 50; // 50 meters from restaurant
    static DELIVERY_RADIUS = 100; // 100 meters from customer

    // Check if rider entered any geofence zones
    async checkGeofences(orderId, riderLat, riderLng) {
        try {
            const tracking = await prisma.orderTracking.findUnique({
                where: { orderId }
            });

            if (!tracking) return;

            const riderLocation = { latitude: riderLat, longitude: riderLng };

            // Check pickup geofence
            if (tracking.status === 'preparing') {
                const pickupLocation = {
                    latitude: tracking.pickupLatitude,
                    longitude: tracking.pickupLongitude
                };

                const distanceToPickup = geolib.getDistance(riderLocation, pickupLocation);

                if (distanceToPickup <= GeofenceService.PICKUP_RADIUS) {
                    await this.triggerGeofenceEvent(tracking, 'arrived_at_restaurant');
                }
            }

            // Check delivery geofence
            if (tracking.status === 'in_transit') {
                const deliveryLocation = {
                    latitude: tracking.destLatitude,
                    longitude: tracking.destLongitude
                };

                const distanceToDelivery = geolib.getDistance(riderLocation, deliveryLocation);

                if (distanceToDelivery <= GeofenceService.DELIVERY_RADIUS) {
                    const updatedTracking = await prisma.orderTracking.update({
                        where: { id: tracking.id },
                        data: {
                            status: 'nearby',
                            lastUpdated: new Date()
                        }
                    });

                    await this.triggerGeofenceEvent(updatedTracking, "arrived_at_customer");
                }
            }

        } catch (error) {
            console.error('Error checking geofences:', error);
        }
    }

    // Trigger geofence event
    async triggerGeofenceEvent(tracking, eventType) {
        // Notify customer via WebSocket
        socketService.emitToUser(tracking.customerId, 'geofence_event', {
            orderId: tracking.orderId,
            eventType,
            status: tracking.status
        });

        // Send push notification using existing FCM service
        const fcmService = require('./fcm_service');

        if (eventType === 'arrived_at_restaurant') {
            await fcmService.sendOrderNotification(
                tracking.customerId,
                tracking.orderId,
                tracking.orderId.substring(0, 8), // Simplified order number
                'rider_at_restaurant',
                'Your rider has arrived at the restaurant'
            );
        } else if (eventType === 'arrived_at_customer') {
            await fcmService.sendDeliveryArrivingNotification(
                tracking.customerId,
                tracking.orderId,
                tracking.orderId.substring(0, 8),
                2 // 2 minutes ETA
            );
        }
    }
}

module.exports = new GeofenceService();