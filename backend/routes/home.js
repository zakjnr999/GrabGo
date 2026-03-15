const express = require('express');
const { protect } = require('../middleware/auth');
const { cacheMiddleware } = require('../middleware/cache');
const cache = require('../utils/cache');
const { fetchFoodHomeFeed } = require('../services/home_feed_service');
const { fetchServiceHubFeed } = require('../services/service_hub_feed_service');
const logger = require('../utils/logger');

const router = express.Router();

const optionalAuth = (req, res, next) => {
  if (req.headers.authorization) {
    return protect(req, res, next);
  }
  return next();
};

router.get(
  '/food-feed',
  optionalAuth,
  cacheMiddleware(cache.CACHE_KEYS.FOOD_HOME_FEED, 180, true),
  async (req, res) => {
    try {
      const feed = await fetchFoodHomeFeed({
        userId: req.user?.id || req.headers['x-user-id'],
        userLat: req.query.userLat,
        userLng: req.query.userLng,
        maxDistance: req.query.maxDistance,
      });

      res.json({
        success: true,
        message: 'Food home feed retrieved successfully',
        data: feed,
      });
    } catch (error) {
      logger.error('home_food_feed_failed', { error });
      res.status(500).json({
        success: false,
        message: 'Server error',
      });
    }
  },
);

router.get(
  '/service-feed',
  optionalAuth,
  cacheMiddleware(cache.CACHE_KEYS.SERVICE_HUB_FEED, 180, true),
  async (req, res) => {
    try {
      const serviceId = req.query.service;

      if (!serviceId) {
        return res.status(400).json({
          success: false,
          message: 'Service is required',
        });
      }

      const feed = await fetchServiceHubFeed({
        serviceId,
        userId: req.user?.id || req.headers['x-user-id'],
        userLat: req.query.userLat,
        userLng: req.query.userLng,
        maxDistance: req.query.maxDistance,
      });

      res.json({
        success: true,
        message: 'Service hub feed retrieved successfully',
        data: feed,
      });
    } catch (error) {
      logger.error('service_hub_feed_failed', {
        service: req.query.service,
        error,
      });
      res.status(500).json({
        success: false,
        message: 'Server error',
      });
    }
  },
);

module.exports = router;
