const express = require('express');
const cache = require('../utils/cache');
const directionsService = require('../services/directions_service');
const { pickupRouteRateLimit } = require('../middleware/fraud_rate_limit');

const router = express.Router();

const parseCoordinate = (value) => {
    if (value === null || value === undefined || value === '') return null;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
};

const isValidLatitude = (value) => Number.isFinite(value) && value >= -90 && value <= 90;
const isValidLongitude = (value) => Number.isFinite(value) && value >= -180 && value <= 180;
const roundCoord = (value) => Number(value).toFixed(4);

router.get('/route', pickupRouteRateLimit, async (req, res) => {
    try {
        const originLat = parseCoordinate(req.query.originLat);
        const originLng = parseCoordinate(req.query.originLng);
        const destinationLat = parseCoordinate(req.query.destinationLat);
        const destinationLng = parseCoordinate(req.query.destinationLng);
        const mode = String(req.query.mode || 'walking').trim().toLowerCase();

        if (
            !isValidLatitude(originLat) ||
            !isValidLongitude(originLng) ||
            !isValidLatitude(destinationLat) ||
            !isValidLongitude(destinationLng)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Valid origin and destination coordinates are required',
            });
        }

        if (mode !== 'walking') {
            return res.status(400).json({
                success: false,
                message: 'Only walking mode is supported for pickup routes',
            });
        }

        if (!directionsService.isConfigured()) {
            return res.status(503).json({
                success: false,
                message: 'Walking routes are unavailable right now',
            });
        }

        const cacheKey = [
            'grabgo:pickup:route',
            mode,
            roundCoord(originLat),
            roundCoord(originLng),
            roundCoord(destinationLat),
            roundCoord(destinationLng),
        ].join(':');

        const cached = await cache.get(cacheKey);
        if (cached) {
            return res.json({
                success: true,
                data: cached,
            });
        }

        const route = await directionsService.getRoute({
            originLat,
            originLng,
            destinationLat,
            destinationLng,
            mode: 'walking',
        });

        if (!route) {
            return res.status(404).json({
                success: false,
                message: 'No walking route is available for this destination',
            });
        }

        const payload = {
            polyline: route.polyline,
            distanceMeters: route.distance,
            durationSeconds: route.duration,
        };

        await cache.set(cacheKey, payload, 60);

        return res.json({
            success: true,
            data: payload,
        });
    } catch (error) {
        console.error('[pickup.route] Failed to fetch walking route:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch walking route',
        });
    }
});

module.exports = router;
