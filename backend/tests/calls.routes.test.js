const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, res, next) => {
    const userId = req.header('x-test-user-id');
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    req.user = { id: userId, role: req.header('x-test-role') || 'customer' };
    return next();
  },
}));

jest.mock('../services/turn_credentials_service', () => ({
  getTurnCredentials: jest.fn(),
}));

const callsRoutes = require('../routes/calls');
const { getTurnCredentials } = require('../services/turn_credentials_service');

const makeApp = (webrtcSignaling) => {
  const app = express();
  app.use(express.json());

  if (webrtcSignaling) {
    app.set('webrtcSignaling', webrtcSignaling);
  }

  app.use('/api/calls', callsRoutes);
  return app;
};

describe('Calls Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /api/calls/turn-credentials', () => {
    test('returns backend TURN credentials for authenticated users', async () => {
      getTurnCredentials.mockResolvedValue({
        iceServers: [{ urls: 'stun:stun.l.google.com:19302' }],
        source: 'provider',
      });

      const app = makeApp({ getCallDetails: jest.fn() });

      const response = await request(app)
        .get('/api/calls/turn-credentials')
        .set('x-test-user-id', 'customer-1');

      expect(response.statusCode).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.callType).toBe('audio');
      expect(response.body.iceServers).toEqual([{ urls: 'stun:stun.l.google.com:19302' }]);
    });

    test('returns 500 when TURN credentials fetch fails', async () => {
      getTurnCredentials.mockRejectedValue(new Error('provider failed'));

      const app = makeApp({ getCallDetails: jest.fn() });

      const response = await request(app)
        .get('/api/calls/turn-credentials')
        .set('x-test-user-id', 'customer-1');

      expect(response.statusCode).toBe(500);
      expect(response.body.success).toBe(false);
      expect(response.body.error).toMatch(/failed to retrieve turn credentials/i);
    });
  });

  describe('GET /api/calls/:callId', () => {
    test('returns 503 when signaling service is unavailable', async () => {
      const app = makeApp(null);

      const response = await request(app)
        .get('/api/calls/call-1')
        .set('x-test-user-id', 'callee-1');

      expect(response.statusCode).toBe(503);
      expect(response.body.error).toMatch(/call service unavailable/i);
    });

    test('returns 404 when call does not exist', async () => {
      const getCallDetails = jest.fn().mockResolvedValue(null);
      const app = makeApp({ getCallDetails });

      const response = await request(app)
        .get('/api/calls/call-1')
        .set('x-test-user-id', 'callee-1');

      expect(response.statusCode).toBe(404);
      expect(response.body.error).toMatch(/not found/i);
    });

    test('returns 403 when requester is not the callee', async () => {
      const getCallDetails = jest.fn().mockResolvedValue({
        callId: 'call-1',
        callerId: 'caller-1',
        calleeId: 'callee-1',
        orderId: 'order-1',
        callType: 'audio',
        offer: { type: 'offer', sdp: 'abc' },
        status: 'ringing',
      });

      const app = makeApp({ getCallDetails });

      const response = await request(app)
        .get('/api/calls/call-1')
        .set('x-test-user-id', 'someone-else');

      expect(response.statusCode).toBe(403);
      expect(response.body.error).toMatch(/unauthorized/i);
    });

    test('returns call details and forces voice call type', async () => {
      const getCallDetails = jest.fn().mockResolvedValue({
        callId: 'call-1',
        callerId: 'caller-1',
        calleeId: 'callee-1',
        orderId: 'order-1',
        callType: 'video',
        offer: { type: 'offer', sdp: 'abc' },
        status: 'ringing',
      });

      const app = makeApp({ getCallDetails });

      const response = await request(app)
        .get('/api/calls/call-1')
        .set('x-test-user-id', 'callee-1');

      expect(response.statusCode).toBe(200);
      expect(response.body.callType).toBe('audio');
      expect(response.body.callId).toBe('call-1');
      expect(response.body.callerId).toBe('caller-1');
      expect(response.body.orderId).toBe('order-1');
    });
  });
});
