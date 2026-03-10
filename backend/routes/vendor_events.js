const express = require('express');
const { protect, authorize } = require('../middleware/auth');
const {
  getAvailableEventCampaignsForVendor,
  upsertRestaurantEventParticipation,
  updateRestaurantEventParticipation,
  updateFoodEventConfig,
} = require('../services/event_campaign_service');
const { sendEventError } = require('./support/event_route_errors');

const router = express.Router();

router.get('/available', protect, authorize('restaurant'), async (req, res) => {
  try {
    const data = await getAvailableEventCampaignsForVendor({ user: req.user });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to load available event campaigns');
  }
});

router.post('/:eventId/participation', protect, authorize('restaurant'), async (req, res) => {
  try {
    const data = await upsertRestaurantEventParticipation({
      user: req.user,
      eventId: req.params.eventId,
      supportsPreorder: req.body?.supportsPreorder,
    });
    return res.status(201).json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to join event campaign');
  }
});

router.patch('/:eventId/participation', protect, authorize('restaurant'), async (req, res) => {
  try {
    const data = await updateRestaurantEventParticipation({
      user: req.user,
      eventId: req.params.eventId,
      data: req.body || {},
    });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to update event participation');
  }
});

router.patch('/foods/:foodId/event-config', protect, authorize('restaurant'), async (req, res) => {
  try {
    const data = await updateFoodEventConfig({
      user: req.user,
      foodId: req.params.foodId,
      data: req.body || {},
    });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to update event item configuration');
  }
});

module.exports = router;
