const express = require('express');
const router = express.Router();
const trackingService = require('../services/tracking_service');
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const {
    ACTION_TYPES,
    buildFraudContextFromRequest,
    fraudDecisionService,
    applyFraudDecision,
} = require('../services/fraud');
const TRACKING_STATUSES = new Set(['preparing', 'picked_up', 'in_transit', 'nearby', 'delivered', 'cancelled']);
const TERMINAL_TRACKING_STATUSES = new Set(['delivered', 'cancelled']);
const NON_AUTHORITATIVE_LIFECYCLE_STATUSES = new Set(['confirmed', 'ready', 'on_the_way']);
const TRACKING_READ_ROLES = new Set(['customer', 'rider', 'admin']);
const TRACKING_WRITE_ROLES = new Set(['rider', 'admin']);
const ORDER_LIFECYCLE_TO_TRACKING_STATUSES = {
    pending: new Set(['preparing']),
    confirmed: new Set(['preparing']),
    preparing: new Set(['preparing']),
    ready: new Set(['preparing']),
    picked_up: new Set(['picked_up']),
    on_the_way: new Set(['in_transit', 'nearby']),
    delivered: new Set(['delivered']),
    cancelled: new Set(['cancelled']),
};

const isValidLatitude = (value) => Number.isFinite(value) && value >= -90 && value <= 90;
const isValidLongitude = (value) => Number.isFinite(value) && value >= -180 && value <= 180;

const parseNumber = (value) => {
    if (value === null || value === undefined || value === '') return null;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
};

const parseLocation = (location) => {
    if (!location || typeof location !== 'object') return null;
    const latitude = parseNumber(location.latitude);
    const longitude = parseNumber(location.longitude);
    if (latitude === null || longitude === null) return null;
    if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) return null;
    return { latitude, longitude };
};

const firstDefined = (...values) =>
    values.find((value) => value !== null && value !== undefined);

const isTrackingStatusAlignedWithOrderLifecycle = (orderStatus, trackingStatus) => {
    const allowedTrackingStatuses = ORDER_LIFECYCLE_TO_TRACKING_STATUSES[orderStatus];
    if (!allowedTrackingStatuses) return false;
    return allowedTrackingStatuses.has(trackingStatus);
};

const getOrderForTracking = async (orderId) => {
    if (!orderId) return null;
    return prisma.order.findUnique({
        where: { id: orderId },
        select: {
            id: true,
            customerId: true,
            riderId: true,
            status: true,
            deliveryLatitude: true,
            deliveryLongitude: true,
        },
    });
};

const getOrderForTrackingInitialization = async (orderId) => {
    if (!orderId) return null;
    return prisma.order.findUnique({
        where: { id: orderId },
        select: {
            id: true,
            customerId: true,
            riderId: true,
            status: true,
            deliveryLatitude: true,
            deliveryLongitude: true,
            restaurant: {
                select: {
                    latitude: true,
                    longitude: true,
                },
            },
            groceryStore: {
                select: {
                    latitude: true,
                    longitude: true,
                },
            },
            pharmacyStore: {
                select: {
                    latitude: true,
                    longitude: true,
                },
            },
            grabMartStore: {
                select: {
                    latitude: true,
                    longitude: true,
                },
            },
        },
    });
};

const canReadTracking = (user, order) => {
    if (!user || !order) return false;
    if (user.role === 'admin') return true;
    if (user.role === 'customer') return order.customerId === user.id;
    if (user.role === 'rider') return !!order.riderId && order.riderId === user.id;
    return false;
};

const canWriteTracking = (user, order) => {
    if (!user || !order) return false;
    if (user.role === 'admin') return true;
    if (user.role === 'rider') return !!order.riderId && order.riderId === user.id;
    return false;
};

const mapErrorStatus = (error) => {
    const message = String(error?.message || '').toLowerCase();
    if (message.includes('not found')) return 404;
    if (message.includes('invalid')) return 400;
    return 500;
};

// Initialize tracking (called when rider accepts order)
router.post('/initialize', protect, async (req, res) => {
    try {
        if (!TRACKING_WRITE_ROLES.has(req.user.role)) {
            return res.status(403).json({
                success: false,
                message: 'Not authorized to initialize tracking',
            });
        }

        const { orderId, pickupLocation, destination } = req.body;
        if (!orderId) {
            return res.status(400).json({
                success: false,
                message: 'orderId is required',
            });
        }

        const order = await getOrderForTrackingInitialization(orderId);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }

        if (!canWriteTracking(req.user, order)) {
            return res.status(403).json({
                success: false,
                message: 'Not authorized for this order',
            });
        }

        if (!order.riderId) {
            return res.status(409).json({
                success: false,
                message: 'Order has no assigned rider yet',
            });
        }
        if (TERMINAL_TRACKING_STATUSES.has(order.status)) {
            return res.status(409).json({
                success: false,
                message: `Order is already ${order.status}; tracking cannot be initialized`,
            });
        }

        const pickupLat = firstDefined(
            order?.restaurant?.latitude,
            order?.groceryStore?.latitude,
            order?.pharmacyStore?.latitude,
            order?.grabMartStore?.latitude
        );
        const pickupLng = firstDefined(
            order?.restaurant?.longitude,
            order?.groceryStore?.longitude,
            order?.pharmacyStore?.longitude,
            order?.grabMartStore?.longitude
        );
        const orderPickup = parseLocation({
            latitude: pickupLat,
            longitude: pickupLng,
        });

        const parsedPickup = orderPickup || parseLocation(pickupLocation);
        const orderDestination = parseLocation({
            latitude: order.deliveryLatitude,
            longitude: order.deliveryLongitude,
        });
        const parsedDestination = orderDestination || parseLocation(destination);

        if (!parsedPickup || !parsedDestination) {
            return res.status(400).json({
                success: false,
                message: 'pickupLocation and destination with valid latitude/longitude are required',
            });
        }

        const tracking = await trackingService.initializeTracking(
            orderId,
            order.riderId,
            order.customerId,
            parsedPickup,
            parsedDestination
        );

        res.status(201).json({
            success: true,
            data: tracking
        });
    } catch (error) {
        res.status(mapErrorStatus(error)).json({
            success: false,
            message: error.message
        });
    }
});

// Update rider location (called by rider app every 5-10 seconds)
router.post('/location', protect, async (req, res) => {
    try {
        if (!TRACKING_WRITE_ROLES.has(req.user.role)) {
            return res.status(403).json({
                success: false,
                message: 'Not authorized to update tracking location',
            });
        }

        const { orderId, latitude, longitude, speed, accuracy } = req.body;
        if (!orderId) {
            return res.status(400).json({
                success: false,
                message: 'orderId is required',
            });
        }

        const order = await getOrderForTracking(orderId);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }

        if (!canWriteTracking(req.user, order)) {
            return res.status(403).json({
                success: false,
                message: 'Not authorized for this order',
            });
        }

        const parsedLat = parseNumber(latitude);
        const parsedLng = parseNumber(longitude);
        const parsedSpeed = parseNumber(speed);
        const parsedAccuracy = parseNumber(accuracy);
        if (parsedLat === null || parsedLng === null) {
            return res.status(400).json({
                success: false,
                message: 'latitude and longitude must be valid numbers',
            });
        }
        if (!isValidLatitude(parsedLat) || !isValidLongitude(parsedLng)) {
            return res.status(400).json({
                success: false,
                message: 'latitude must be between -90 and 90 and longitude between -180 and 180',
            });
        }
        if (parsedSpeed !== null && parsedSpeed < 0) {
            return res.status(400).json({
                success: false,
                message: 'speed must be a non-negative number',
            });
        }
        if (parsedAccuracy !== null && parsedAccuracy < 0) {
            return res.status(400).json({
                success: false,
                message: 'accuracy must be a non-negative number',
            });
        }

        if (TERMINAL_TRACKING_STATUSES.has(order.status)) {
            return res.status(409).json({
                success: false,
                message: `Order is already ${order.status}; location updates are no longer accepted`,
            });
        }

        const locationAnomaly = (parsedSpeed !== null && parsedSpeed > 50) || (parsedAccuracy !== null && parsedAccuracy > 1000);
        const fraudContext = buildFraudContextFromRequest({
            req,
            actionType: ACTION_TYPES.RIDER_STATUS_UPDATE,
            actorType: req.user.role || 'rider',
            actorId: req.user.id,
            extras: {
                orderId,
                status: order.status,
                metadata: {
                    latitude: parsedLat,
                    longitude: parsedLng,
                    speed: parsedSpeed,
                    accuracy: parsedAccuracy,
                    locationAnomaly,
                    highValueOrder: false,
                    riderAgeDays: null,
                },
            },
        });

        const fraudDecision = await fraudDecisionService.evaluate({
            actionType: ACTION_TYPES.RIDER_STATUS_UPDATE,
            actorType: req.user.role || 'rider',
            actorId: req.user.id,
            context: fraudContext,
        });

        const fraudGate = applyFraudDecision({
            req,
            res,
            decision: fraudDecision,
            actionType: ACTION_TYPES.RIDER_STATUS_UPDATE,
        });
        if (fraudGate.blocked || fraudGate.challenged) return;

        const tracking = await trackingService.updateRiderLocation(
            orderId,
            parsedLat,
            parsedLng,
            parsedSpeed ?? 0,
            parsedAccuracy ?? 0
        );

        res.json({
            success: true,
            data: {
                distanceRemaining: tracking.distanceRemaining,
                estimatedArrival: tracking.estimatedArrival,
                etaSeconds: tracking.etaSeconds,
                status: tracking.status
            }
        });
    } catch (error) {
        res.status(mapErrorStatus(error)).json({
            success: false,
            message: error.message
        });
    }
});

// Update order status
router.patch('/status', protect, async (req, res) => {
    try {
        if (!TRACKING_WRITE_ROLES.has(req.user.role)) {
            return res.status(403).json({
                success: false,
                message: 'Not authorized to update tracking status',
            });
        }

        const { orderId, status } = req.body;
        if (!orderId || !status) {
            return res.status(400).json({
                success: false,
                message: 'orderId and status are required',
            });
        }
        if (!TRACKING_STATUSES.has(status)) {
            return res.status(400).json({
                success: false,
                message: `Invalid tracking status: ${status}`,
            });
        }
        if (TERMINAL_TRACKING_STATUSES.has(status)) {
            return res.status(400).json({
                success: false,
                message: `Status ${status} must be updated via /orders/:orderId/status`,
            });
        }

        const order = await getOrderForTracking(orderId);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }

        if (!canWriteTracking(req.user, order)) {
            return res.status(403).json({
                success: false,
                message: 'Not authorized for this order',
            });
        }
        if (TERMINAL_TRACKING_STATUSES.has(order.status)) {
            return res.status(409).json({
                success: false,
                message: `Order is already ${order.status}; tracking status updates are no longer accepted`,
            });
        }
        if (!isTrackingStatusAlignedWithOrderLifecycle(order.status, status)) {
            return res.status(409).json({
                success: false,
                message: `Tracking status "${status}" is not valid while order lifecycle status is "${order.status}". Update /orders/:orderId/status first.`,
            });
        }

        if (NON_AUTHORITATIVE_LIFECYCLE_STATUSES.has(status)) {
            console.warn(`[tracking/status] Lifecycle status "${status}" received for order ${orderId}. Use /orders/:orderId/status as source of truth.`);
        }

        const fraudContext = buildFraudContextFromRequest({
            req,
            actionType: ACTION_TYPES.RIDER_STATUS_UPDATE,
            actorType: req.user.role || 'rider',
            actorId: req.user.id,
            extras: {
                orderId,
                status,
                metadata: {
                    orderLifecycleStatus: order.status,
                    locationAnomaly: false,
                    highValueOrder: false,
                    riderAgeDays: null,
                },
            },
        });

        const fraudDecision = await fraudDecisionService.evaluate({
            actionType: ACTION_TYPES.RIDER_STATUS_UPDATE,
            actorType: req.user.role || 'rider',
            actorId: req.user.id,
            context: fraudContext,
        });

        const fraudGate = applyFraudDecision({
            req,
            res,
            decision: fraudDecision,
            actionType: ACTION_TYPES.RIDER_STATUS_UPDATE,
        });
        if (fraudGate.blocked || fraudGate.challenged) return;

        const tracking = await trackingService.updateOrderStatus(orderId, status);

        res.json({
            success: true,
            data: tracking
        });
    } catch (error) {
        res.status(mapErrorStatus(error)).json({
            success: false,
            message: error.message
        });
    }
});

// Get tracking info (called by customer app)
router.get('/:orderId', protect, async (req, res) => {
    try {
        if (!TRACKING_READ_ROLES.has(req.user.role)) {
            return res.status(403).json({
                success: false,
                message: 'Not authorized to view tracking',
            });
        }

        const orderId = req.params.orderId;
        const order = await getOrderForTracking(orderId);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }

        if (!canReadTracking(req.user, order)) {
            return res.status(403).json({
                success: false,
                message: 'Not authorized for this order',
            });
        }

        const tracking = await trackingService.getTrackingInfo(orderId);

        res.json({
            success: true,
            data: tracking
        });
    } catch (error) {
        res.status(mapErrorStatus(error)).json({
            success: false,
            message: error.message
        });
    }
});

module.exports = router;
