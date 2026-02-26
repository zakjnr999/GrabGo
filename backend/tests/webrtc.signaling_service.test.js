const callStore = new Map();
const socketStore = new Map();
const userCallStore = new Map();

jest.mock('../utils/cache', () => ({
  isRedisConnected: jest.fn(() => false),
  set: jest.fn(async (key, value) => {
    if (key.startsWith('webrtc:call:')) {
      callStore.set(key.replace('webrtc:call:', ''), value);
    } else if (key.startsWith('webrtc:socket:')) {
      socketStore.set(key.replace('webrtc:socket:', ''), value);
    } else if (key.startsWith('webrtc:user-call:')) {
      userCallStore.set(key.replace('webrtc:user-call:', ''), value);
    }
    return true;
  }),
  get: jest.fn(async (key) => {
    if (key.startsWith('webrtc:call:')) {
      return callStore.get(key.replace('webrtc:call:', '')) || null;
    }
    if (key.startsWith('webrtc:socket:')) {
      return socketStore.get(key.replace('webrtc:socket:', '')) || null;
    }
    if (key.startsWith('webrtc:user-call:')) {
      return userCallStore.get(key.replace('webrtc:user-call:', '')) || null;
    }
    return null;
  }),
  del: jest.fn(async (key) => {
    if (key.startsWith('webrtc:call:')) {
      callStore.delete(key.replace('webrtc:call:', ''));
    } else if (key.startsWith('webrtc:socket:')) {
      socketStore.delete(key.replace('webrtc:socket:', ''));
    } else if (key.startsWith('webrtc:user-call:')) {
      userCallStore.delete(key.replace('webrtc:user-call:', ''));
    }
    return true;
  }),
}));

jest.mock('../services/fcm_service', () => ({
  sendCallNotification: jest.fn(),
}));

jest.mock('../config/prisma', () => ({
  order: {
    findUnique: jest.fn(),
  },
  user: {
    findUnique: jest.fn(),
  },
}));

jest.mock('../models/CallLog', () => ({
  create: jest.fn().mockResolvedValue({ id: 'log-1' }),
}));

const prisma = require('../config/prisma');
const WebRTCSignalingService = require('../services/webrtcSignalingService');

const createIoMock = () => {
  const connectionHandlers = [];
  const emitted = [];

  return {
    emitted,
    on: jest.fn((event, handler) => {
      if (event === 'connection') {
        connectionHandlers.push(handler);
      }
    }),
    triggerConnection: (socket) => {
      for (const handler of connectionHandlers) {
        handler(socket);
      }
    },
    to: jest.fn((socketId) => ({
      emit: (event, payload) => {
        emitted.push({ socketId, event, payload });
      },
    })),
  };
};

const createSocket = (userId, socketId = `socket-${userId}`) => ({
  id: socketId,
  data: { userId },
  on: jest.fn(),
  emit: jest.fn(),
});

describe('WebRTCSignalingService', () => {
  let io;
  let service;

  beforeEach(() => {
    jest.useFakeTimers();

    callStore.clear();
    socketStore.clear();
    userCallStore.clear();
    jest.clearAllMocks();

    prisma.order.findUnique.mockResolvedValue({
      id: 'order-1',
      customerId: 'customer-1',
      riderId: 'rider-1',
      status: 'on_the_way',
    });

    prisma.user.findUnique.mockResolvedValue({
      username: 'Caller',
      profilePicture: null,
    });

    io = createIoMock();
    service = new WebRTCSignalingService(io);
  });

  afterEach(() => {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
  });

  test('rejects non-audio call initiation payload', async () => {
    const socket = createSocket('customer-1');

    await service.handleCallInitiation(socket, {
      calleeId: 'rider-1',
      callerId: 'customer-1',
      orderId: 'order-1',
      offer: { type: 'offer', sdp: 'fake-sdp' },
      callType: 'video',
    });

    expect(socket.emit).toHaveBeenCalledWith(
      'webrtc:error',
      expect.objectContaining({
        code: 'UNSUPPORTED_CALL_TYPE',
      })
    );
    expect(service.activeCalls.size).toBe(0);
  });

  test('rejects caller identity mismatch against authenticated socket user', async () => {
    const socket = createSocket('customer-1');

    await service.handleCallInitiation(socket, {
      calleeId: 'rider-1',
      callerId: 'attacker-1',
      orderId: 'order-1',
      offer: { type: 'offer', sdp: 'fake-sdp' },
      callType: 'audio',
    });

    expect(socket.emit).toHaveBeenCalledWith(
      'webrtc:error',
      expect.objectContaining({
        code: 'CALLER_ID_MISMATCH',
      })
    );
    expect(service.activeCalls.size).toBe(0);
  });

  test('rejects calls when caller/callee are not participants in the order', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-1',
      customerId: 'customer-1',
      riderId: 'rider-1',
      status: 'on_the_way',
    });

    const socket = createSocket('intruder-1');

    await service.handleCallInitiation(socket, {
      calleeId: 'rider-1',
      callerId: 'intruder-1',
      orderId: 'order-1',
      offer: { type: 'offer', sdp: 'fake-sdp' },
      callType: 'audio',
    });

    expect(socket.emit).toHaveBeenCalledWith(
      'webrtc:error',
      expect.objectContaining({
        code: 'ORDER_PARTICIPANT_REQUIRED',
      })
    );
    expect(service.activeCalls.size).toBe(0);
  });

  test('stores voice-only call and forwards incoming-call to callee when online', async () => {
    const socket = createSocket('customer-1', 'caller-socket');
    await service.setUserSocket('rider-1', 'callee-socket');

    await service.handleCallInitiation(socket, {
      calleeId: 'rider-1',
      callerId: 'customer-1',
      orderId: 'order-1',
      offer: { type: 'offer', sdp: 'fake-sdp' },
      callType: 'audio',
    });

    const activeCalls = Array.from(service.activeCalls.values());
    expect(activeCalls).toHaveLength(1);
    expect(activeCalls[0].callType).toBe('audio');

    expect(io.emitted).toContainEqual(
      expect.objectContaining({
        socketId: 'callee-socket',
        event: 'webrtc:incoming-call',
      })
    );

    expect(socket.emit).toHaveBeenCalledWith(
      'webrtc:call-ringing',
      expect.objectContaining({
        callId: expect.any(String),
      })
    );
  });

  test('only callee can answer a call', async () => {
    const callId = 'call-1';

    await service.setActiveCall(callId, {
      callId,
      callerId: 'customer-1',
      calleeId: 'rider-1',
      orderId: 'order-1',
      callType: 'audio',
      status: 'ringing',
      startedAt: new Date().toISOString(),
      offer: { type: 'offer', sdp: 'fake-sdp' },
    });

    await service.setUserSocket('customer-1', 'caller-socket');

    const intruderSocket = createSocket('intruder-1');
    await service.handleCallAnswer(intruderSocket, {
      callId,
      answer: { type: 'answer', sdp: 'answer-sdp' },
    });

    expect(intruderSocket.emit).toHaveBeenCalledWith(
      'webrtc:error',
      expect.objectContaining({ code: 'ANSWER_NOT_ALLOWED' })
    );

    const calleeSocket = createSocket('rider-1');
    await service.handleCallAnswer(calleeSocket, {
      callId,
      answer: { type: 'answer', sdp: 'answer-sdp' },
    });

    const updatedCall = await service.getActiveCall(callId);
    expect(updatedCall.status).toBe('active');

    expect(io.emitted).toContainEqual(
      expect.objectContaining({
        socketId: 'caller-socket',
        event: 'webrtc:call-answered',
      })
    );
  });

  test('routes ICE candidate only to the other call participant', async () => {
    const callId = 'call-1';

    await service.setActiveCall(callId, {
      callId,
      callerId: 'customer-1',
      calleeId: 'rider-1',
      orderId: 'order-1',
      callType: 'audio',
      status: 'active',
      startedAt: new Date().toISOString(),
      answeredAt: new Date().toISOString(),
      offer: { type: 'offer', sdp: 'fake-sdp' },
    });

    await service.setUserSocket('rider-1', 'callee-socket');
    await service.setUserSocket('customer-1', 'caller-socket');

    const callerSocket = createSocket('customer-1', 'caller-socket');
    await service.handleIceCandidate(callerSocket, {
      callId,
      targetUserId: 'random-user',
      candidate: {
        candidate: 'candidate:1 1 UDP 2122260223 10.0.0.1 8998 typ host',
        sdpMid: '0',
        sdpMLineIndex: 0,
      },
    });

    expect(io.emitted).toContainEqual(
      expect.objectContaining({
        socketId: 'callee-socket',
        event: 'webrtc:ice-candidate',
      })
    );

    expect(io.emitted).not.toContainEqual(
      expect.objectContaining({
        socketId: 'random-user',
      })
    );
  });
});
