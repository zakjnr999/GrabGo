const express = require('express');
const { protect, authorize } = require('../middleware/auth');
const {
  createEventCampaign,
  updateEventCampaign,
  listEventParticipants,
  updateEventParticipantStatus,
  getEventAudiencePreview,
  scheduleEventNotifications,
} = require('../services/event_campaign_service');
const { sendEventError } = require('./support/event_route_errors');

const router = express.Router();

router.post('/', protect, authorize('admin'), async (req, res) => {
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

router.patch('/:id', protect, authorize('admin'), async (req, res) => {
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

router.get('/:id/audience-preview', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await getEventAudiencePreview({ eventId: req.params.id });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to preview event audience');
  }
});

router.post('/:id/schedule-notifications', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await scheduleEventNotifications({ eventId: req.params.id });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to schedule event campaign notifications');
  }
});

router.get('/:id/participants', protect, authorize('admin'), async (req, res) => {
  try {
    const data = await listEventParticipants({ eventId: req.params.id });
    return res.json({ success: true, data });
  } catch (error) {
    return sendEventError(res, error, 'Failed to load event participants');
  }
});

router.patch('/:id/participants/:restaurantId', protect, authorize('admin'), async (req, res) => {
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

module.exports = router;
