const geolib = require('geolib');
const OrderTracking = require('../models/OrderTracking');
const socketService = require('./socket_service');

class GeofenceService {

    // Geofence radiuses in meters
    static PICKUP_RADIUS = 50; // 50 meters from restaurant
    static DELIVERY_RADIUS = 100; // 100 meters from customer

    // Check if rider entered any geofence zones
    async checkGeofences(orderId, riderLat, riderLng) {
        try {
            const tracking = await OrderTracking.findOne({ orderId });
            if (!tracking) return;

            const riderLocation = { latitude: riderLat, longitude: riderLng };

            //check pickup geofence
            if (tracking.status === 'preparing') {
                const pickupLocation = {
                    latitude: tracking.pickupLocation.coordinates[1],
                    longitude: tracking.pickupLocation.coordinates[0]
                };

                const distanceToPickup = geolib.getDistance(riderLocation, pickupLocation);

                if (distanceToPickup <= GeofenceService.PICKUP_RADIUS) {
                    await this.triggerGeofenceEvent(tracking, 'arrived_at_restaurant');
                }
            }

            // check delivery geofence
            if (tracking.status === 'in_transit') {
                const deliveryLocation = {
                    latitude: tracking.destination.coordinates[1],
                    longitude: tracking.destination.coordinates[0]
                };

                const distanceToDelivery = geolib.getDistance(riderLocation, deliveryLocation);

                if (distanceToDelivery <= GeofenceService.DELIVERY_RADIUS) {
                    tracking.status = 'nearby';
                    await tracking.save();

                    await this.triggerGeofenceEvent(tracking, "arrived_at_customer");
                }
            }

        } catch (error) {
            console.error('Error checking geofences:', error);
        }
    }

    // Trigger geofence event
    async triggerGeofenceEvent(tracking, eventType) {
        // Should notify customer
        socketService.emitToUser(tracking.customerId.toString(), 'geofence_event', {
            orderId: tracking.orderId.toString(),
            eventType,
            status: tracking.status
        });

        // Send push notification using existing FCM service
        const fcmService = require('./fcm_service');

        if (eventType === 'arrived_at_restaurant') {
            await fcmService.sendOrderNotification(
                tracking.customerId,
                tracking.orderId,
                tracking.orderId.toString().slice(-6), // Use last 6 chars as order number
                'rider_at_restaurant',
                'Your rider has arrived at the restaurant'
            );
        } else if (eventType === 'arrived_at_customer') {
            await fcmService.sendDeliveryArrivingNotification(
                tracking.customerId,
                tracking.orderId,
                tracking.orderId.toString().slice(-6),
                2 // 2 minutes ETA
            );
        }
    }
}

module.exports = new GeofenceService();