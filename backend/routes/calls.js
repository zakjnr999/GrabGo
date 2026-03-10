const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { callTurnCredentialsRateLimit } = require('../middleware/fraud_rate_limit');
const { createScopedLogger } = require('../utils/logger');
const { getTurnCredentials } = require('../services/turn_credentials_service');

const VOICE_CALL_TYPE = 'audio';
const console = createScopedLogger('calls_route');

const sendCallsError = (res, error, fallbackMessage, fallbackStatus = 500) => {
  const explicitStatus = Number(error?.status);
  const status =
    Number.isInteger(explicitStatus) && explicitStatus >= 400 && explicitStatus < 600
      ? explicitStatus
      : fallbackStatus;

  return res.status(status).json({
    error: status >= 500 ? fallbackMessage : String(error?.message || fallbackMessage),
  });
};

// Get short-lived TURN credentials for WebRTC voice calls.
router.get('/turn-credentials', protect, callTurnCredentialsRateLimit, async (req, res) => {
  try {
    const turnCredentials = await getTurnCredentials();

    res.json({
      success: true,
      callType: VOICE_CALL_TYPE,
      ...turnCredentials,
    });
  } catch (error) {
    console.error('Error retrieving TURN credentials:', error);
    return sendCallsError(res, error, 'Failed to retrieve TURN credentials');
  }
});

// Get call details (for when user comes online after receiving notification)
router.get('/:callId', protect, async (req, res) => {
  try {
    const { callId } = req.params;
    const userId = req.user.id;

    const webrtcSignaling = req.app.get('webrtcSignaling');
    if (!webrtcSignaling || typeof webrtcSignaling.getCallDetails !== 'function') {
      return res.status(503).json({ error: 'Call service unavailable' });
    }

    const call = await webrtcSignaling.getCallDetails(callId);

    if (!call) {
      return res.status(404).json({ error: 'Call not found or expired' });
    }

    // Only the callee can retrieve call details for answering from a push notification.
    if (call.calleeId !== userId) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    res.json({
      callId: call.callId,
      callerId: call.callerId,
      orderId: call.orderId,
      callType: VOICE_CALL_TYPE,
      offer: call.offer,
      status: call.status,
    });
  } catch (error) {
    console.error('Error retrieving call details:', error);
    return sendCallsError(res, error, 'Failed to retrieve call details');
  }
});

module.exports = router;
