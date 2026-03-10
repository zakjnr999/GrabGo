const express = require('express');
const { protect, authorize } = require('../middleware/auth');
const {
  createEventCampaign,
  updateEventCampaign,
  getActiveEventCampaigns,
  getEventCampaignDetailBySlug,
  getEventCampaignVendorsBySlug,
  getEventCampaignItemsBySlug,
  getAvailableEventCampaignsForVendor,
  upsertRestaurantEventParticipation,
  updateRestaurantEventParticipation,
  updateFoodEventConfig,
  listEventParticipants,
  updateEventParticipantStatus,
  getEventAudiencePreview,
  scheduleEventNotifications,
} = require('../services/event_campaign_service');
const { sendEventError } = require('./support/event_route_errors');

const router = express.Router();

router.get('/active', async (req, res) => {
  try {
    const data = await getActiveEventCampaigns();
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to load active event campaigns');
  }
});

router.get('/vendor/available', protect, authorize('restaurant'), async (req, res) => {
  try {
    const data = await getAvailableEventCampaignsForVendor({ user: req.user });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to load available event campaigns');
  }
});

router.post('/vendor/:eventId/participation', protect, authorize('restaurant'), async (req, res) => {
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

router.patch('/vendor/:eventId/participation', protect, authorize('restaurant'), async (req, res) => {
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

router.patch('/vendor/foods/:foodId/event-config', protect, authorize('restaurant'), async (req, res) => {
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

router.post('/admin', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await createEventCampaign({
      data: req.body || {},
      createdById: req.user?.id || null,
    });
    return res.status(201).json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to create event campaign');
  }
});

router.patch('/admin/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await updateEventCampaign({
      eventId: req.params.id,
      data: req.body || {},
    });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to update event campaign');
  }
});

router.get('/admin/:id/audience-preview', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await getEventAudiencePreview({ eventId: req.params.id });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to preview event audience');
  }
});

router.post('/admin/:id/schedule-notifications', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await scheduleEventNotifications({ eventId: req.params.id });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to schedule event campaign notifications');
  }
});

router.get('/admin/:id/participants', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await listEventParticipants({ eventId: req.params.id });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to load event participants');
  }
});

router.patch('/admin/:id/participants/:restaurantId', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await updateEventParticipantStatus({
      eventId: req.params.id,
      restaurantId: req.params.restaurantId,
      data: req.body || {},
    });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to update event participant');
  }
});

router.get('/:slug/vendors', async (req, res) => {
  try {
    const data = await getEventCampaignVendorsBySlug({
      slug: req.params.slug,
      userLat: req.query.userLat,
      userLng: req.query.userLng,
      maxDistanceKm: req.query.maxDistance,
      limit: req.query.limit,
    });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to load event vendors');
  }
});

router.get('/:slug/items', async (req, res) => {
  try {
    const data = await getEventCampaignItemsBySlug({
      slug: req.params.slug,
      userLat: req.query.userLat,
      userLng: req.query.userLng,
      maxDistanceKm: req.query.maxDistance,
      limit: req.query.limit,
    });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to load event items');
  }
});

router.get('/:slug', async (req, res) => {
  try {
    const data = await getEventCampaignDetailBySlug({ slug: req.params.slug });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to load event campaign');
  }
});

module.exports = router;
