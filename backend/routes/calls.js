const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { getTurnCredentials } = require('../services/turn_credentials_service');

const VOICE_CALL_TYPE = 'audio';

// Get short-lived TURN credentials for WebRTC voice calls.
router.get('/turn-credentials', protect, async (req, res) => {
  try {
    const turnCredentials = await getTurnCredentials();

    res.json({
      success: true,
      callType: VOICE_CALL_TYPE,
      ...turnCredentials,
    });
  } catch (error) {
    console.error('Error retrieving TURN credentials:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve TURN credentials',
    });
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
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
