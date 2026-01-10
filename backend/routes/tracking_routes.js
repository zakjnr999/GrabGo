const express = require('express');
const router = express.Router();
const trackingService = require('../services/tracking_service');
const auth = require('../middleware/auth');

// Initialize tracking (called when rider accepts order)
router.post('/initialize', auth, async (req, res) => {
    try {
        const { orderId, riderId, customerId, pickupLocation, destination } = req.body;

        const tracking = await trackingService.initializeTracking(
            orderId,
            riderId,
            customerId,
            pickupLocation,
            destination
        );

        res.status(201).json({
            success: true,
            data: tracking
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// Update rider location (called by rider app every 5-10 seconds)
router.post('/location', auth, async (req, res) => {
    try {
        const { orderId, latitude, longitude, speed, accuracy } = req.body;

        const tracking = await trackingService.updateRiderLocation(
            orderId,
            latitude,
            longitude,
            speed,
            accuracy
        );

        res.json({
            success: true,
            data: {
                distanceRemaining: tracking.distanceRemaining,
                estimatedArrival: tracking.estimatedArrival,
                status: tracking.status
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// Update order status
router.patch('/status', auth, async (req, res) => {
    try {
        const { orderId, status } = req.body;

        const tracking = await trackingService.updateOrderStatus(orderId, status);

        res.json({
            success: true,
            data: tracking
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// Get tracking info (called by customer app)
router.get('/:orderId', auth, async (req, res) => {
    try {
        const  tracking = await trackingService.getTrackingInfo(req.params.orderId);

        res.json({
            success: true,
            data: tracking
        });
    } catch (error) {
        res.status(404).json({
            success: false,
            message: error.message
        });
    }
});

module.exports = router;