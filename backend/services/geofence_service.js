const geolib = require('geolib');
const OrderTracking = require('../models/OrderTracking');
const socketService = require('./socket_service');
const cache = require('../utils/cache');

const ORDER_TRACKING_ENTITY = 'order';
const buildOrderTrackingQuery = (query = {}) =>
    OrderTracking.buildEntityQuery(ORDER_TRACKING_ENTITY, query);

const GEOFENCE_EVENT_TTL_SECONDS = 30 * 60;
const makeGeofenceEventKey = (orderId, eventType) =>
    `grabgo:tracking:geofence:${orderId}:${eventType}`;

class GeofenceService {

    // Geofence radiuses in meters
    static PICKUP_RADIUS = 50; // 50 meters from restaurant
    static DELIVERY_RADIUS = 100; // 100 meters from customer

    async shouldEmitGeofenceEvent(orderId, eventType) {
        const key = makeGeofenceEventKey(orderId, eventType);
        try {
            const hasRecentEvent = await cache.get(key);
            if (hasRecentEvent) {
                return false;
            }
            await cache.set(key, true, GEOFENCE_EVENT_TTL_SECONDS);
            return true;
        } catch (error) {
            console.error('Geofence dedupe cache error:', error.message);
            // Fail-open: still emit event if cache is unavailable.
            return true;
        }
    }

    // Check if rider entered any geofence zones
    async checkGeofences(orderId, riderLat, riderLng) {
        try {
            const tracking = await OrderTracking.findOne(
                buildOrderTrackingQuery({
                    orderId: orderId.toString(),
                    status: { $nin: ['delivered', 'cancelled'] }
                })
            );

            if (!tracking) return;

            const riderLocation = { latitude: riderLat, longitude: riderLng };

            // Check pickup geofence (GeoJSON format: [longitude, latitude])
            if (tracking.status === 'preparing') {
                const pickupLocation = {
                    latitude: tracking.pickupLocation.coordinates[1],
                    longitude: tracking.pickupLocation.coordinates[0]
                };

                const distanceToPickup = geolib.getDistance(riderLocation, pickupLocation);

                if (distanceToPickup <= GeofenceService.PICKUP_RADIUS) {
                    const shouldEmit = await this.shouldEmitGeofenceEvent(
                        tracking.orderId,
                        'arrived_at_restaurant'
                    );
                    if (shouldEmit) {
                        await this.triggerGeofenceEvent(tracking, 'arrived_at_restaurant');
                    }
                }
            }

            // Check delivery geofence
            if (tracking.status !== 'delivered' && tracking.status !== 'cancelled') {
                const deliveryLocation = {
                    latitude: tracking.destination.coordinates[1],
                    longitude: tracking.destination.coordinates[0]
                };

                const distanceToDelivery = geolib.getDistance(riderLocation, deliveryLocation);

                if (distanceToDelivery <= GeofenceService.DELIVERY_RADIUS) {
                    if (tracking.status === 'in_transit') {
                        tracking.status = 'nearby';
                        tracking.lastUpdated = new Date();
                        await tracking.save();
                    }

                    const shouldEmit = await this.shouldEmitGeofenceEvent(
                        tracking.orderId,
                        'arrived_at_customer'
                    );
                    if (shouldEmit) {
                        await this.triggerGeofenceEvent(tracking, "arrived_at_customer");
                    }
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
