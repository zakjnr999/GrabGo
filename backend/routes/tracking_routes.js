const express = require('express');
const router = express.Router();
const trackingService = require('../services/tracking_service');
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const TRACKING_STATUSES = new Set(['preparing', 'picked_up', 'in_transit', 'nearby', 'delivered', 'cancelled']);
const NON_AUTHORITATIVE_LIFECYCLE_STATUSES = new Set(['confirmed', 'ready', 'on_the_way']);
const TRACKING_READ_ROLES = new Set(['customer', 'rider', 'admin']);
const TRACKING_WRITE_ROLES = new Set(['rider', 'admin']);

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
    return { latitude, longitude };
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

        if (!order.riderId) {
            return res.status(409).json({
                success: false,
                message: 'Order has no assigned rider yet',
            });
        }

        const parsedPickup = parseLocation(pickupLocation);
        const orderDestination =
            parseNumber(order.deliveryLatitude) !== null && parseNumber(order.deliveryLongitude) !== null
                ? {
                    latitude: Number(order.deliveryLatitude),
                    longitude: Number(order.deliveryLongitude),
                }
                : null;
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
        if (parsedLat === null || parsedLng === null) {
            return res.status(400).json({
                success: false,
                message: 'latitude and longitude must be valid numbers',
            });
        }

        const tracking = await trackingService.updateRiderLocation(
            orderId,
            parsedLat,
            parsedLng,
            speed,
            accuracy
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

        if (NON_AUTHORITATIVE_LIFECYCLE_STATUSES.has(status)) {
            console.warn(`[tracking/status] Lifecycle status "${status}" received for order ${orderId}. Use /orders/:orderId/status as source of truth.`);
        }

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
