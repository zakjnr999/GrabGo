const { EventCampaignError } = require('../../services/event_campaign_service');
const logger = require('../../utils/logger');

const sendEventError = (res, error, fallbackMessage = 'Failed to process event campaign request') => {
  if (error instanceof EventCampaignError) {
    return res.status(error.status).json({
      success: false,
      message: error.message,
      code: error.code,
      ...(error.meta ? { meta: error.meta } : {}),
    });
  }

  logger.error('event_campaign_route_failed', { error });
  return res.status(500).json({
    success: false,
    message: fallbackMessage,
  });
};

module.exports = {
  sendEventError,
};
