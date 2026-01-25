const { Client } = require('@googlemaps/google-maps-services-js');
const geolib = require('geolib');
const geofenceService = require('./geofence_service');
const OrderTracking = require('../models/OrderTracking');
const socketService = require('./socket_service');
const prisma = require('../config/prisma');

const googleMapsClient = new Client({});
const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

class TrackingService {
    /**
     * Initialize tracking for a new order in MongoDB
     */
    async initializeTracking(orderId, riderId, customerId, pickupLocation, destination) {
        try {
            const tracking = new OrderTracking({
                orderId: orderId.toString(),
                riderId: riderId.toString(),
                customerId: customerId.toString(),
                pickupLocation: {
                    type: 'Point',
                    coordinates: [pickupLocation.longitude, pickupLocation.latitude]
                },
                destination: {
                    type: 'Point',
                    coordinates: [destination.longitude, destination.latitude]
                },
                status: 'preparing'
            });

            await tracking.save();
            console.log(`📍 Tracking initialized in MongoDB for order ${orderId}`);
            return tracking;
        } catch (error) {
            console.error('❌ Error initializing tracking:', error);
            throw error;
        }
    }

    /**
     * Update rider's current location in MongoDB
     */
    async updateRiderLocation(orderId, latitude, longitude, speed = 0, accuracy = 0) {
        try {
            const tracking = await OrderTracking.findOne({
                orderId: orderId.toString(),
                status: { $nin: ['delivered', 'cancelled'] }
            });

            if (!tracking) {
                console.warn(`⚠️ Active tracking not found for order ${orderId}`);
                throw new Error('Active tracking not found for this order');
            }

            // Update current location (GeoJSON format: [long, lat])
            tracking.currentLocation = {
                type: 'Point',
                coordinates: [longitude, latitude]
            };

            // Add to embedded location history in MongoDB
            tracking.locationHistory.push({
                coordinates: [longitude, latitude],
                timestamp: new Date(),
                speed,
                accuracy
            });

            // Keep only last 100 locations to prevent document bloat
            if (tracking.locationHistory.length > 100) {
                tracking.locationHistory = tracking.locationHistory.slice(-100);
            }

            // Calculate distance to destination
            const distance = geolib.getDistance(
                { latitude, longitude },
                {
                    latitude: tracking.destination.coordinates[1],
                    longitude: tracking.destination.coordinates[0]
                }
            );

            tracking.distanceRemaining = distance;

            // Update status based on distance
            if (distance < 100 && tracking.status === 'in_transit') {
                tracking.status = 'nearby';
            }

            // Calculate ETA
            const eta = await this.calculateETA(latitude, longitude, tracking.destination.coordinates);
            tracking.estimatedArrival = eta.arrivalTime;
            tracking.route = eta.route;

            tracking.lastUpdated = new Date();
            await tracking.save();

            // Prepare update data for real-time broadcast
            const updateData = {
                orderId: orderId.toString(),
                location: { latitude, longitude },
                distance: distance,
                eta: eta.duration,
                status: tracking.status,
                route: tracking.route
            };

            // Broadcast update to order room
            socketService.emitToOrder(orderId.toString(), 'location_update', updateData);

            // Also emit to specific customer
            socketService.emitToUser(tracking.customerId.toString(), 'location_update', updateData);

            // Check geofences (automated notifications)
            if (geofenceService && typeof geofenceService.checkGeofences === 'function') {
                await geofenceService.checkGeofences(orderId, latitude, longitude);
            }

            return tracking;
        } catch (error) {
            console.error('❌ Error updating rider location:', error);
            throw error;
        }
    }

    /**
     * Calculate ETA using Google Maps Distance Matrix API
     */
    async calculateETA(fromLat, fromLng, toCoordinates) {
        try {
            if (!GOOGLE_MAPS_API_KEY) {
                return this.calculateStraightLineETA(fromLat, fromLng, toCoordinates);
            }

            const response = await googleMapsClient.distancematrix({
                params: {
                    origins: [`${fromLat},${fromLng}`],
                    destinations: [`${toCoordinates[1]},${toCoordinates[0]}`],
                    mode: 'driving',
                    departure_time: 'now',
                    traffic_model: 'best_guess',
                    key: GOOGLE_MAPS_API_KEY
                }
            });

            const result = response.data.rows[0].elements[0];

            if (result.status === 'OK') {
                const durationInSeconds = result.duration_in_traffic ? result.duration_in_traffic.value : result.duration.value;

                // Get route polyline
                const directions = await this.getDirections(fromLat, fromLng, toCoordinates);

                return {
                    duration: durationInSeconds,
                    distance: result.distance.value,
                    arrivalTime: new Date(Date.now() + durationInSeconds * 1000),
                    route: directions
                };
            }

            return this.calculateStraightLineETA(fromLat, fromLng, toCoordinates);
        } catch (error) {
            console.error('⚠️ ETA Calculation error (falling back to straight line):', error.message);
            return this.calculateStraightLineETA(fromLat, fromLng, toCoordinates);
        }
    }

    /**
     * Get directions polyline for route visualization
     */
    async getDirections(fromLat, fromLng, toCoordinates) {
        try {
            if (!GOOGLE_MAPS_API_KEY) return null;

            const response = await googleMapsClient.directions({
                params: {
                    origin: `${fromLat},${fromLng}`,
                    destination: `${toCoordinates[1]},${toCoordinates[0]}`,
                    mode: 'driving',
                    key: GOOGLE_MAPS_API_KEY
                }
            });

            if (response.data.routes.length > 0) {
                const route = response.data.routes[0];
                return {
                    polyline: route.overview_polyline.points,
                    duration: route.legs[0].duration.value,
                    distance: route.legs[0].distance.value
                };
            }

            return null;
        } catch (error) {
            console.error('Error getting directions:', error);
            return null;
        }
    }

    /**
     * Fallback ETA calculation (straight line)
     */
    calculateStraightLineETA(fromLat, fromLng, toCoordinates) {
        const distance = geolib.getDistance(
            { latitude: fromLat, longitude: fromLng },
            { latitude: toCoordinates[1], longitude: toCoordinates[0] }
        );

        // Assume average speed of 30 km/h (8.33 m/s)
        const averageSpeed = 8.33;
        const duration = Math.round(distance / averageSpeed);

        return {
            duration,
            distance,
            arrivalTime: new Date(Date.now() + duration * 1000),
            route: null
        };
    }

    /**
     * Update order status in MongoDB
     */
    async updateOrderStatus(orderId, status) {
        try {
            const tracking = await OrderTracking.findOneAndUpdate(
                { orderId: orderId.toString() },
                {
                    $set: {
                        status,
                        lastUpdated: new Date()
                    }
                },
                { new: true }
            );

            if (!tracking) {
                throw new Error('Tracking not found');
            }

            // Notify customer in real-time
            socketService.emitToUser(tracking.customerId.toString(), 'order_status_update', {
                orderId: orderId.toString(),
                status
            });

            return tracking;
        } catch (error) {
            console.error('❌ Error updating order status:', error);
            throw error;
        }
    }

    /**
     * Get current tracking info (Hydrated from PostgreSQL)
     */
    async getTrackingInfo(orderId) {
        try {
            const tracking = await OrderTracking.findOne({ orderId: orderId.toString() }).lean();

            if (!tracking) {
                throw new Error('Tracking not found');
            }

            // Manual hydration from PostgreSQL (Prisma)
            const [rider, customer] = await Promise.all([
                prisma.user.findUnique({
                    where: { id: tracking.riderId },
                    select: { id: true, username: true, phone: true }
                }),
                prisma.user.findUnique({
                    where: { id: tracking.customerId },
                    select: { id: true, username: true, phone: true }
                })
            ]);

            return {
                ...tracking,
                rider,
                customer
            };
        } catch (error) {
            console.error('❌ Error getting tracking info:', error);
            throw error;
        }
    }
}

module.exports = new TrackingService();