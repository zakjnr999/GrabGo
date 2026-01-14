const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');

// Get call details (for when user comes online after receiving notification)
router.get('/:callId', protect, async (req, res) => {
  try {
    const { callId } = req.params;
    const userId = req.user._id.toString();

    // Get WebRTC signaling service instance
    const webrtcSignaling = req.app.get('webrtcSignaling');
    const call = await webrtcSignaling.getCallDetails(callId);

    if (!call) {
      return res.status(404).json({ error: 'Call not found or expired' });
    }

    // Verify user is the callee
    if (call.calleeId !== userId) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    // Return call details
    res.json({
      callId: call.callId,
      callerId: call.callerId,
      orderId: call.orderId,
      callType: call.callType,
      offer: call.offer,
      status: call.status,
    });
  } catch (error) {
    console.error('Error retrieving call details:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;