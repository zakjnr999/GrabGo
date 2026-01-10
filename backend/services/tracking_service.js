const { Client } = require('@googlemaps/google-maps-services-js');
const geolib = require('geolib');
const geofenceService = require('./geofence_service');
const OrderTracking = require('../models/OrderTracking');
const socketService = require('./socket_service');

const googleMapsClient = new Client({});
const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

class TrackingService {
    // Initialize tracking for a new order

    async initializeTracking(orderId, riderId, customerId, pickupLocation, destination) {
        try {
            const tracking = new OrderTracking({
                orderId,
                riderId,
                customerId,
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
            return tracking;
        } catch (error) {
            console.error('Error initializing tracking:', error);
            throw error;
        }
    }

    //Update rider's current location

    async updateRiderLocation(orderId, latitude, longitude, speed = 0, accuracy = 0) {
        try {
            const tracking = await OrderTracking.findOne({ orderId, status: { $nin: ['delivered', 'cancelled'] } });

            if (!tracking) {
                throw new Error('Active tracking not found for this order');
            }

            // Update current location
            tracking.currentLocation = {
                type: 'Point',
                coordinates: [longitude, latitude]
            };

            // Add to location history
            tracking.locationHistory.push({
                coordinates: [longitude, latitude],
                timestamp: new Date(),
                speed,
                accuracy
            });

            // Keep only last 100 locations
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

            //Update status based on distance
            if (distance < 100 && tracking.status === 'in_transit') {
                tracking.status = 'nearby';
            }

            // Calculate ETA
            const eta = await this.calculateETA(latitude, longitude, tracking.destination.coordinates);
            tracking.estimatedArrival = eta.arrivalTime;
            tracking.route = eta.route;

            tracking.lastUpdated = new Date();
            await tracking.save();

            // Broadcast update to customer via Socket.IO
            socketService.emitToUser(tracking.customerId.toString(), 'location_update', {
                orderId: orderId.toString(),
                location: { latitude, longitude },
                distance: distance,
                eta: eta.duration,
                status: tracking.status,
                route: tracking.route
            });

            // check geofences
            await geofenceService.checkGeofences(orderId, latitude, longitude);

            return tracking;
        } catch (error) {
            console.error('Error updating rider location:', error);
            throw error;
        }
    }

    // Calculate ETA using Google Maps Distance Matrix API
    async calculateETA(fromLat, fromLng, toCoordinates) {
        try {
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

            //Fallback to straight-line calculation
            return this.calculateStraightLineETA(fromLat, fromLng, toCoordinates);
        } catch (error) {
            console.error('Error calculating ETA:', error);
            return this.calculateStraightLineETA(fromLat, fromLng, toCoordinates);
        }
    }

    // Get directions polyline for route visuallization
    async getDirections(fromLat, fromLng, toCoordinates) {
        try {
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

    //Fallback ETA calculation (straight line)
    calculateStraightLineETA(fromLat, fromLng, toCoordinates) {
        const distance = geolib.getDistance(
            { latitude: fromLat, longitude: fromLng },
            { latitude: toCoordinates[1], longitude: toCoordinates[0] }
        );

        // Assume average speed of 30 km/h in city
        const averageSpeed = 30 * 1000 / 3600; // m/s
        const duration = Math.round(distance / averageSpeed);

        return {
            duration,
            distance,
            arrivalTime: new Date(Date.now() + duration * 1000),
            route: null
        };
    }

    //Update order status
    async updateOrderStatus(orderId, status) {
        try {
            const tracking = await OrderTracking.findOne({ orderId });

            if (!tracking) {
                throw new Error('Tracking not found');
            }

            tracking.status = status;
            tracking.lastUpdated = new Date();
            await tracking.save();

            // Notify customer
            socketService.emitToUser(tracking.customerId.toString(), 'order_status_update', {
                orderId: orderId.toString(),
                status
            });

            return tracking;
        } catch (error) {
            console.error('Error updating order status:', error);
            throw error;
        }
    }

    // Get current tracking info
    async getTrackingInfo(orderId) {
        try {
            const tracking = await OrderTracking.findOne({ orderId })
                .populate('riderId', 'name phone profileImage')
                .populate('customerId', 'name phone');

            if (!tracking) {
                throw new Error('Tracking not found');
            }

            return tracking;
        } catch (error) {
            console.error('Error getting tracking info:', error);
            throw error;
        }
    }
}

module.exports = new TrackingService();