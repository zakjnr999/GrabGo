const { Client } = require('@googlemaps/google-maps-services-js');
const geolib = require('geolib');
const geofenceService = require('./geofence_service');
const OrderTracking = require('../models/OrderTracking');
const socketService = require('./socket_service');
const prisma = require('../config/prisma');
const cache = require('../utils/cache');
const mlClient = require('../utils/ml_client');

const ORDER_TRACKING_ENTITY = 'order';
const buildOrderTrackingQuery = (query = {}) =>
    OrderTracking.buildEntityQuery(ORDER_TRACKING_ENTITY, query);
const buildOrderTrackingUpsertQuery = (orderId) => ({
    orderId,
    $or: [{ entityType: ORDER_TRACKING_ENTITY }, { entityType: { $exists: false } }]
});

const googleMapsClient = new Client({});
const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

// Configuration for Redis-based location caching
const LOCATION_CACHE_TTL = 30;
const MONGO_PERSIST_INTERVAL = 10000;
const LOCATION_HISTORY_BATCH_SIZE = 5;
const NON_AUTHORITATIVE_LIFECYCLE_STATUSES = new Set(['confirmed', 'ready', 'on_the_way']);

class TrackingService {
    constructor() {
        // Track pending location updates per order (for batching)
        this.pendingLocations = new Map();
        // Track last MongoDB persist time per order
        this.lastPersistTime = new Map();
    }
    /**
     * Initialize tracking for a new order in MongoDB
     */
    async initializeTracking(orderId, riderId, customerId, pickupLocation, destination) {
        try {
            const orderIdStr = orderId.toString();
            const riderIdStr = riderId.toString();
            const customerIdStr = customerId.toString();

            const tracking = await OrderTracking.findOneAndUpdate(
                buildOrderTrackingUpsertQuery(orderIdStr),
                {
                    $set: {
                        entityType: ORDER_TRACKING_ENTITY,
                        riderId: riderIdStr,
                        customerId: customerIdStr,
                        pickupLocation: {
                            type: 'Point',
                            coordinates: [pickupLocation.longitude, pickupLocation.latitude]
                        },
                        destination: {
                            type: 'Point',
                            coordinates: [destination.longitude, destination.latitude]
                        },
                        lastUpdated: new Date()
                    },
                    $setOnInsert: {
                        status: 'preparing'
                    }
                },
                { upsert: true, new: true, runValidators: true }
            );

            console.log(`📍 Tracking initialized in MongoDB for order ${orderId}`);
            return tracking;
        } catch (error) {
            console.error('❌ Error initializing tracking:', error);
            throw error;
        }
    }

    /**
     * Update rider's current location with Redis caching for performance
     * Stores latest location in Redis for fast reads, batches writes to MongoDB
     */
    async updateRiderLocation(orderId, latitude, longitude, speed = 0, accuracy = 0) {
        try {
            const orderIdStr = orderId.toString();
            const cacheKey = cache.makeKey(cache.CACHE_KEYS.ORDER_TRACKING, orderIdStr);
            const now = Date.now();

            // Try to get tracking metadata from cache first
            let trackingMeta = await cache.get(cacheKey);

            if (!trackingMeta) {
                // Cache miss - fetch from MongoDB and cache it
                const tracking = await OrderTracking.findOne(
                    buildOrderTrackingQuery({
                        orderId: orderIdStr,
                        status: { $nin: ['delivered', 'cancelled'] }
                    })
                ).lean();

                if (!tracking) {
                    console.warn(`⚠️ Active tracking not found for order ${orderId}`);
                    throw new Error('Active tracking not found for this order');
                }

                trackingMeta = {
                    orderId: orderIdStr,
                    riderId: tracking.riderId,
                    customerId: tracking.customerId,
                    destination: tracking.destination,
                    pickupLocation: tracking.pickupLocation,
                    status: tracking.status,
                    route: tracking.route,
                    distanceRemaining: tracking.distanceRemaining,
                    estimatedArrival: tracking.estimatedArrival
                };

                // Cache tracking metadata (longer TTL since it rarely changes)
                await cache.set(cacheKey, trackingMeta, 300); // 5 minutes
            }

            // Store current location in Redis (fast write)
            const locationKey = cache.makeKey(cache.CACHE_KEYS.RIDER_LOCATION, orderIdStr);
            const locationData = {
                latitude,
                longitude,
                speed,
                accuracy,
                timestamp: now
            };
            await cache.set(locationKey, locationData, LOCATION_CACHE_TTL);

            // Calculate distance to destination
            const distance = geolib.getDistance(
                { latitude, longitude },
                {
                    latitude: trackingMeta.destination.coordinates[1],
                    longitude: trackingMeta.destination.coordinates[0]
                }
            );

            // Check if status should change
            let status = trackingMeta.status;
            if (distance < 100 && status === 'in_transit') {
                status = 'nearby';
                trackingMeta.status = status;
                await cache.set(cacheKey, trackingMeta, 300);
            }

            // Calculate ETA (throttle to avoid excessive API calls)
            let eta = { duration: null, route: trackingMeta.route };
            const lastEtaKey = `${cacheKey}:lastEta`;
            const lastEtaTime = await cache.get(lastEtaKey);

            // Only recalculate ETA every 30 seconds
            if (!lastEtaTime || (now - lastEtaTime) > 30000) {
                eta = await this.calculateETA(latitude, longitude, trackingMeta.destination.coordinates);
                await cache.set(lastEtaKey, now, 60);

                // Update route in cached metadata if changed
                if (eta.route) {
                    trackingMeta.route = eta.route;
                    await cache.set(cacheKey, trackingMeta, 300);
                }
            }

            const etaSeconds = typeof eta.duration === 'number' ? eta.duration : null;
            const estimatedArrival =
                eta.arrivalTime ||
                (etaSeconds !== null ? new Date(now + etaSeconds * 1000) : trackingMeta.estimatedArrival || null);

            trackingMeta.distanceRemaining = distance;
            trackingMeta.estimatedArrival = estimatedArrival;
            trackingMeta.status = status;
            trackingMeta.route = eta.route || trackingMeta.route || null;
            await cache.set(cacheKey, trackingMeta, 300);

            // Prepare update data for real-time broadcast
            const updateData = {
                orderId: orderIdStr,
                location: { latitude, longitude },
                distanceRemaining: distance,
                estimatedArrival,
                etaSeconds,
                distance,
                eta: etaSeconds,
                status,
                route: eta.route || trackingMeta.route
            };

            // Broadcast update to order room (immediate)
            socketService.emitToOrder(orderIdStr, 'location_update', updateData);
            socketService.emitToUser(trackingMeta.customerId.toString(), 'location_update', updateData);

            // Queue location for batch persistence to MongoDB
            await this._queueLocationForPersistence(orderIdStr, {
                coordinates: [longitude, latitude],
                timestamp: new Date(now),
                speed,
                accuracy
            }, distance, status, {
                arrivalTime: estimatedArrival,
                route: updateData.route
            });

            // Check geofences (automated notifications)
            if (geofenceService && typeof geofenceService.checkGeofences === 'function') {
                await geofenceService.checkGeofences(orderId, latitude, longitude);
            }

            return {
                ...trackingMeta,
                currentLocation: locationData,
                status,
                distanceRemaining: distance,
                estimatedArrival,
                etaSeconds,
                distance,
                eta: etaSeconds
            };
        } catch (error) {
            console.error('❌ Error updating rider location:', error);
            throw error;
        }
    }

    /**
     * Queue location updates and batch persist to MongoDB
     * Reduces MongoDB write operations significantly
     */
    async _queueLocationForPersistence(orderId, locationEntry, distance, status, eta) {
        // Initialize queue for this order if not exists
        if (!this.pendingLocations.has(orderId)) {
            this.pendingLocations.set(orderId, []);
        }

        const queue = this.pendingLocations.get(orderId);
        queue.push(locationEntry);

        const lastPersist = this.lastPersistTime.get(orderId) || 0;
        const now = Date.now();
        const shouldPersist =
            queue.length >= LOCATION_HISTORY_BATCH_SIZE ||
            (now - lastPersist) >= MONGO_PERSIST_INTERVAL;

        if (shouldPersist) {
            await this._persistToMongoDB(orderId, queue, distance, status, eta);
            this.pendingLocations.set(orderId, []);
            this.lastPersistTime.set(orderId, now);
        }
    }

    /**
     * Persist batched location updates to MongoDB
     */
    async _persistToMongoDB(orderId, locationBatch, distance, status, eta) {
        try {
            const latestLocation = locationBatch[locationBatch.length - 1];

            await OrderTracking.findOneAndUpdate(
                buildOrderTrackingQuery({ orderId }),
                {
                    $set: {
                        currentLocation: {
                            type: 'Point',
                            coordinates: latestLocation.coordinates
                        },
                        distanceRemaining: distance,
                        status,
                        estimatedArrival: eta.arrivalTime || null,
                        route: eta.route || null,
                        lastUpdated: new Date()
                    },
                    $push: {
                        locationHistory: {
                            $each: locationBatch,
                            $slice: -100 // Keep only last 100
                        }
                    }
                }
            );

            console.log(`📍 Persisted ${locationBatch.length} locations to MongoDB for order ${orderId}`);
        } catch (error) {
            console.error(`❌ Error persisting locations for order ${orderId}:`, error);
            // Don't throw - we don't want to break the real-time flow
        }
    }

    /**
     * Get rider's current location from Redis (fast) with MongoDB fallback
     */
    async getRiderLocation(orderId) {
        const orderIdStr = orderId.toString();
        const locationKey = cache.makeKey(cache.CACHE_KEYS.RIDER_LOCATION, orderIdStr);

        // Try Redis first
        const cachedLocation = await cache.get(locationKey);
        if (cachedLocation) {
            return cachedLocation;
        }

        // Fallback to MongoDB
        const tracking = await OrderTracking.findOne(
            buildOrderTrackingQuery({ orderId: orderIdStr }),
            { currentLocation: 1 }
        ).lean();

        if (tracking?.currentLocation) {
            return {
                latitude: tracking.currentLocation.coordinates[1],
                longitude: tracking.currentLocation.coordinates[0],
                timestamp: tracking.lastUpdated
            };
        }

        return null;
    }

    /**
     * Flush pending locations to MongoDB (call on order completion or server shutdown)
     */
    async flushPendingLocations(orderId = null) {
        const ordersToFlush = orderId
            ? [orderId]
            : Array.from(this.pendingLocations.keys());

        for (const oid of ordersToFlush) {
            const queue = this.pendingLocations.get(oid);
            if (queue && queue.length > 0) {
                // Get latest tracking data for the flush
                const cacheKey = cache.makeKey(cache.CACHE_KEYS.ORDER_TRACKING, oid);
                const meta = await cache.get(cacheKey);

                await this._persistToMongoDB(
                    oid,
                    queue,
                    meta?.distanceRemaining || 0,
                    meta?.status || 'in_transit',
                    { arrivalTime: null, route: meta?.route }
                );
                this.pendingLocations.delete(oid);
                this.lastPersistTime.delete(oid);
            }
        }

        console.log(`📍 Flushed pending locations for ${ordersToFlush.length} orders`);
    }

    /**
     * Clear tracking cache when order is completed/cancelled
     */
    async clearTrackingCache(orderId) {
        const orderIdStr = orderId.toString();
        await this.flushPendingLocations(orderIdStr);
        await cache.del(cache.makeKey(cache.CACHE_KEYS.ORDER_TRACKING, orderIdStr));
        await cache.del(cache.makeKey(cache.CACHE_KEYS.RIDER_LOCATION, orderIdStr));
        await cache.del(`${cache.makeKey(cache.CACHE_KEYS.ORDER_TRACKING, orderIdStr)}:lastEta`);
        console.log(`🗑️ Cleared tracking cache for order ${orderId}`);
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
     * Uses 15 km/h for city traffic (Ghana conditions)
     */
    calculateStraightLineETA(fromLat, fromLng, toCoordinates) {
        const distance = geolib.getDistance(
            { latitude: fromLat, longitude: fromLng },
            { latitude: toCoordinates[1], longitude: toCoordinates[0] }
        );

        // Assume average speed of 15 km/h (4.17 m/s) for Ghana city traffic
        const averageSpeed = 4.17;
        const duration = Math.round(distance / averageSpeed);

        return {
            duration,
            distance,
            arrivalTime: new Date(Date.now() + duration * 1000),
            route: null
        };
    }

    /**
     * Calculate initial delivery window when rider accepts order
     * Uses hybrid approach: Google Maps for traffic + ML for human factors (Prep, Rider Performance)
     * 
     * @param {Object} riderLocation - {latitude, longitude}
     * @param {Object} vendorLocation - {latitude, longitude}
     * @param {Object} customerLocation - {latitude, longitude}
     * @param {string} orderStatus - Current order status (affects prep time)
     * @param {number} vendorPrepTime - Vendor's average preparation time in minutes (default 15)
     * @param {string} riderId - (Optional) UUID of the rider
     * @param {string} restaurantId - (Optional) UUID of the restaurant/store
     * @param {number} itemsCount - (Optional) Number of items in order
     * @returns {Object} Delivery window with min/max times
     */
    async calculateInitialDeliveryWindow(
        riderLocation,
        vendorLocation,
        customerLocation,
        orderStatus = 'confirmed',
        vendorPrepTime = 15,
        riderId = null,
        restaurantId = null,
        itemsCount = 1,
        orderId = null
    ) {
        try {
            // 1. Get Traffic-Aware Driving Times from Google Maps (King of Maps API)
            // Phase 1: Rider → Vendor
            const phase1 = await this.calculateETA(
                riderLocation.latitude,
                riderLocation.longitude,
                [vendorLocation.longitude, vendorLocation.latitude]
            );

            // Phase 3: Vendor → Customer
            const phase3 = await this.calculateETA(
                vendorLocation.latitude,
                vendorLocation.longitude,
                [customerLocation.longitude, customerLocation.latitude]
            );

            // 2. Get "Human Intelligence" from ML Service (Prep time & Rider speed patterns)
            let mlFactors = null;
            if (mlClient) {
                mlFactors = await mlClient.predictDeliveryFactors({
                    orderId,
                    riderId,
                    restaurantId,
                    itemsCount,
                    restaurantLocation: { latitude: vendorLocation.latitude, longitude: vendorLocation.longitude },
                    deliveryLocation: { latitude: customerLocation.latitude, longitude: customerLocation.longitude }
                });
            }

            // 3. Combine Google (Maps) + ML (Human Factors)

            // Use ML prep time if available, otherwise use vendor average or fallback
            let prepTimeMinutes = mlFactors?.factors?.preparation_time_minutes || vendorPrepTime;

            // Adjust prep time based on current status
            switch (orderStatus) {
                case 'ready':
                    prepTimeMinutes = 2; // Minimal buffer, already ready
                    break;
                case 'preparing':
                    prepTimeMinutes = Math.ceil(prepTimeMinutes / 2); // Halfway done
                    break;
                case 'confirmed':
                case 'pending':
                default:
                    // Use full ML predicted prep time
                    break;
            }

            const riderMultiplier = mlFactors?.factors?.rider_multiplier || 1.0;
            const trafficMultiplier = mlFactors?.factors?.traffic_multiplier || 1.0; // ML's view on time of day

            // Calculate totals (applying rider multiplier to the travel phases)
            const travelSeconds = (phase1.duration + phase3.duration) * riderMultiplier;
            const prepSeconds = prepTimeMinutes * 60;

            const totalSeconds = Math.round(travelSeconds + prepSeconds);

            // Add safety buffer: 5 minutes default
            const bufferSeconds = 5 * 60;

            // Calculate delivery window
            const now = Date.now();
            const minDeliveryTime = new Date(now + totalSeconds * 1000);
            const expectedDeliveryTime = new Date(now + (totalSeconds + bufferSeconds) * 1000);
            const maxDeliveryTime = new Date(now + (totalSeconds + bufferSeconds * 2) * 1000);

            // Convert to minutes for display
            const totalMinutes = Math.ceil(totalSeconds / 60);
            const minMinutes = totalMinutes;
            const maxMinutes = totalMinutes + 10; // +10 minute window

            console.log(`🤖 Hybrid ETA (Google + ML):
                Phase 1 (Rider→Vendor): ${Math.ceil(phase1.duration / 60)} mins (Original)
                Phase 2 (Prep Time): ${prepTimeMinutes} mins (ML Predicted)
                Phase 3 (Vendor→Customer): ${Math.ceil(phase3.duration / 60)} mins (Original)
                Rider Performance: x${riderMultiplier.toFixed(2)}
                Total ETA: ${totalMinutes} mins
                Window: ${minMinutes}-${maxMinutes} mins`);

            return {
                // Breakdown
                riderToVendorMinutes: Math.ceil((phase1.duration * riderMultiplier) / 60),
                riderToVendorDistance: phase1.distance,
                prepTimeMinutes,
                vendorToCustomerMinutes: Math.ceil((phase3.duration * riderMultiplier) / 60),
                vendorToCustomerDistance: phase3.distance,

                // Totals
                totalMinutes,
                totalDistance: phase1.distance + phase3.distance,

                // Delivery window
                minMinutes,
                maxMinutes,
                minDeliveryTime,
                maxDeliveryTime,
                expectedDeliveryTime,

                // Display string
                deliveryWindowText: `${minMinutes}-${maxMinutes} mins`,

                // Initial ETA in seconds (for analytics)
                initialETASeconds: totalSeconds,
                usingML: !!mlFactors
            };
        } catch (error) {
            console.error('❌ Error calculating delivery window (falling back):', error);

            // Standard fallback logic (the original one)
            const totalDistance = geolib.getDistance(
                { latitude: riderLocation.latitude, longitude: riderLocation.longitude },
                { latitude: customerLocation.latitude, longitude: customerLocation.longitude }
            );

            const travelMinutes = Math.ceil(totalDistance / 250); // ~15 km/h
            const totalMinutes = travelMinutes + vendorPrepTime;

            return {
                riderToVendorMinutes: Math.ceil(travelMinutes / 2),
                prepTimeMinutes: vendorPrepTime,
                vendorToCustomerMinutes: Math.ceil(travelMinutes / 2),
                totalMinutes,
                totalDistance,
                minMinutes: totalMinutes,
                maxMinutes: totalMinutes + 10,
                minDeliveryTime: new Date(Date.now() + totalMinutes * 60 * 1000),
                maxDeliveryTime: new Date(Date.now() + (totalMinutes + 10) * 60 * 1000),
                expectedDeliveryTime: new Date(Date.now() + (totalMinutes + 5) * 60 * 1000),
                deliveryWindowText: `${totalMinutes}-${totalMinutes + 10} mins`,
                initialETASeconds: totalMinutes * 60,
                usingML: false
            };
        }
    }

    /**
     * Update order status in MongoDB and cache
     */
    async updateOrderStatus(orderId, status) {
        try {
            const orderIdStr = orderId.toString();

            if (NON_AUTHORITATIVE_LIFECYCLE_STATUSES.has(status)) {
                console.warn(`[tracking_service] Non-authoritative lifecycle status "${status}" written to tracking for order ${orderIdStr}.`);
            }

            const tracking = await OrderTracking.findOneAndUpdate(
                buildOrderTrackingQuery({ orderId: orderIdStr }),
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

            // Update cached metadata
            const cacheKey = cache.makeKey(cache.CACHE_KEYS.ORDER_TRACKING, orderIdStr);
            const cachedMeta = await cache.get(cacheKey);
            if (cachedMeta) {
                cachedMeta.status = status;
                await cache.set(cacheKey, cachedMeta, 300);
            }

            // Flush pending locations and clear cache on terminal states
            if (status === 'delivered' || status === 'cancelled') {
                await this.clearTrackingCache(orderIdStr);
            }

            // Notify customer in real-time
            socketService.emitToUser(tracking.customerId.toString(), 'order_status_update', {
                orderId: orderIdStr,
                status
            });

            return tracking;
        } catch (error) {
            console.error('❌ Error updating order status:', error);
            throw error;
        }
    }

    /**
     * Get current tracking info with Redis-cached location (Hydrated from PostgreSQL)
     */
    async getTrackingInfo(orderId) {
        try {
            const orderIdStr = orderId.toString();

            // Try to get current location from Redis first (most up-to-date)
            const cachedLocation = await this.getRiderLocation(orderIdStr);

            const tracking = await OrderTracking.findOne(
                buildOrderTrackingQuery({ orderId: orderIdStr })
            ).lean();

            if (!tracking) {
                throw new Error('Tracking not found');
            }

            // Override with cached location if available (more recent than MongoDB)
            if (cachedLocation) {
                tracking.currentLocation = {
                    type: 'Point',
                    coordinates: [cachedLocation.longitude, cachedLocation.latitude]
                };
                tracking.lastUpdated = cachedLocation.timestamp;
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
