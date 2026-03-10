const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, res, next) => {
    const role = req.header('x-test-role');
    const userId = req.header('x-test-user-id');
    if (!role || !userId) {
      return res.status(401).json({ success: false, message: 'Not authorized' });
    }
    req.user = { id: userId, role, email: req.header('x-test-email') || null };
    return next();
  },
  authorize: (...roles) => (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authorized' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    return next();
  },
}));

jest.mock('../middleware/upload', () => ({
  uploadSingle: () => (_req, _res, next) => next(),
  uploadToCloudinary: (_req, _res, next) => next(),
}));

jest.mock('../middleware/withdrawal_guard', () => ({
  withdrawalBalanceGuard: (_req, _res, next) => next(),
}));

jest.mock('../middleware/fraud_rate_limit', () => ({
  withdrawalRateLimit: (_req, _res, next) => next(),
}));

jest.mock('../config/feature_flags', () => ({
  isRiderAvailableIncludeConfirmed: false,
  riderAvailableMaxRadiusKm: 20,
  isConfirmedPredispatchEnabled: false,
}));

jest.mock('../utils/logger', () => ({
  createScopedLogger: jest.fn(() => ({
    log: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  })),
}));

jest.mock('../config/prisma', () => ({
  order: {
    findUnique: jest.fn(),
    findMany: jest.fn(),
    update: jest.fn(),
  },
  chat: {
    findUnique: jest.fn(),
    create: jest.fn(),
  },
}));

jest.mock('../services/dispatch_service', () => ({
  acceptReservation: jest.fn(),
  getActiveReservationForRider: jest.fn(),
  declineReservation: jest.fn(),
}));

jest.mock('../services/dispatch_retry_service', () => ({
  markRetryResolved: jest.fn().mockResolvedValue(undefined),
  enqueueDispatchRetry: jest.fn(),
  resetDispatchAttemptHistory: jest.fn(),
  isRecoverableDispatchFailure: jest.fn(() => false),
}));

jest.mock('../services/fcm_service', () => ({
  sendOrderNotification: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../services/notification_service', () => ({
  createNotification: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../utils/socket', () => ({
  getIO: jest.fn(() => ({ io: true })),
}));

jest.mock('../services/socket_service', () => ({
  emitToUserRoom: jest.fn(),
  broadcastOrderTaken: jest.fn(),
}));

jest.mock('../services/fraud', () => ({
  ACTION_TYPES: {
    RIDER_ACCEPT_ORDER: 'RIDER_ACCEPT_ORDER',
  },
  buildFraudContextFromRequest: jest.fn(() => ({ requestId: 'fraud-ctx-1' })),
  fraudDecisionService: {
    evaluate: jest.fn().mockResolvedValue({ decision: 'allow' }),
  },
  applyFraudDecision: jest.fn(() => ({ blocked: false, challenged: false })),
}));

jest.mock('../services/rider_partner_service', () => ({}));
jest.mock('../services/rider_quest_engine', () => ({ getRiderQuestDashboard: jest.fn() }));
jest.mock('../services/rider_streak_engine', () => ({ getRiderStreakDashboard: jest.fn() }));
jest.mock('../services/rider_milestone_engine', () => ({ getRiderMilestoneDashboard: jest.fn() }));
jest.mock('../services/rider_incentive_orchestrator', () => ({ getRiderIncentiveSummary: jest.fn() }));
jest.mock('../services/rider_peak_hour_service', () => ({ getCurrentPeakStatus: jest.fn(), getPeakHourSchedule: jest.fn() }));
jest.mock('../services/rider_budget_service', () => ({ getBudgetDashboard: jest.fn(), updateBudgetCap: jest.fn(), runBudgetApprovalCycle: jest.fn() }));
jest.mock('../services/rider_payout_service', () => ({
  getWithdrawalPolicyInfo: jest.fn(),
  calculateWithdrawalFee: jest.fn(),
  createInstantPayoutRequest: jest.fn(),
  recordInstantWithdrawal: jest.fn(),
}));
jest.mock('../services/rider_loan_service', () => ({
  getLoanEligibility: jest.fn(),
  applyForLoan: jest.fn(),
  getRiderLoans: jest.fn(),
  getLoanDetail: jest.fn(),
}));

jest.mock('../models/OrderReservation', () => ({
  buildEntityQuery: jest.fn((_entityType, query) => query),
  find: jest.fn(),
  findById: jest.fn(),
  findOne: jest.fn(),
}));

jest.mock('../models/OrderTracking', () => ({
  buildEntityQuery: jest.fn((entityType, query) => ({ entityType, ...query })),
  findOneAndDelete: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../models/RiderStatus', () => ({
  findOne: jest.fn(),
  findOneAndUpdate: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../services/tracking_service', () => ({
  initializeTracking: jest.fn().mockResolvedValue(undefined),
  calculateInitialDeliveryWindow: jest.fn().mockResolvedValue({
    minMinutes: 10,
    maxMinutes: 15,
    expectedDeliveryTime: new Date('2026-03-10T12:00:00.000Z'),
    initialETASeconds: 780,
    deliveryWindowText: '10-15 min',
  }),
}));

jest.mock('../utils/riderEarningsCalculator', () => ({
  calculateRiderEarnings: jest.fn(() => ({
    riderBaseFee: 8,
    riderDistanceFee: 4,
    riderTip: 0,
    platformFee: 2,
    riderEarnings: 12,
    distance: 3.4,
  })),
  calculateDistance: jest.fn(() => 2.1),
}));

const prisma = require('../config/prisma');
const OrderReservation = require('../models/OrderReservation');
const RiderStatus = require('../models/RiderStatus');
const dispatchService = require('../services/dispatch_service');
const dispatchRetryService = require('../services/dispatch_retry_service');
const socketService = require('../services/socket_service');
const ridersRoutes = require('../routes/riders');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/riders', ridersRoutes);
  return app;
};

const withAuth = (req, { role = 'rider', userId = 'rider-1', email = 'rider@example.com' } = {}) =>
  req.set('x-test-role', role).set('x-test-user-id', userId).set('x-test-email', email);

describe('Riders Routes - extracted flow regressions', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    OrderReservation.find.mockReturnValue({
      select: jest.fn().mockResolvedValue([]),
      sort: jest.fn().mockReturnThis(),
      limit: jest.fn().mockResolvedValue([]),
    });
    OrderReservation.findOne.mockResolvedValue(null);
    RiderStatus.findOne.mockResolvedValue({
      location: { coordinates: [-0.15, 5.58] },
    });
    prisma.chat.findUnique.mockResolvedValue(null);
    prisma.chat.create.mockResolvedValue({ id: 'chat-1' });
    prisma.order.update.mockResolvedValue({
      id: 'order-1',
      orderNumber: 'ORD-1',
      customerId: 'customer-1',
      riderId: 'rider-1',
      status: 'picked_up',
      items: [{ id: 'item-1' }],
      rider: { username: 'Yaw', phone: '233555000111' },
      restaurant: { latitude: 5.6, longitude: -0.1, averagePreparationTime: 18 },
      deliveryLatitude: 5.7,
      deliveryLongitude: -0.12,
    });
  });

  test('returns available orders with earnings and statistics', async () => {
    prisma.order.findMany.mockResolvedValue([
      {
        id: 'order-1',
        orderNumber: 'ORD-1',
        status: 'ready',
        fulfillmentMode: 'delivery',
        paymentStatus: 'paid',
        totalAmount: 40,
        customer: { id: 'customer-1', username: 'Kofi' },
        restaurant: {
          restaurantName: 'Cafe Moka',
          latitude: 5.6,
          longitude: -0.1,
        },
        items: [{ id: 'item-1', name: 'Latte', quantity: 1, price: 40 }],
      },
    ]);

    const response = await withAuth(
      request(app).get('/api/riders/available-orders?lat=5.60&lon=-0.14&radius=10')
    );

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.orders).toHaveLength(1);
    expect(response.body.data.orders[0]).toMatchObject({
      id: 'order-1',
      riderEarnings: 12,
      distance: 3.4,
      distanceToPickup: 2.1,
    });
    expect(response.body.data.statistics).toMatchObject({
      totalOrders: 1,
      totalEarnings: 12,
      filterApplied: true,
      radius: 20,
      expandedRadius: true,
    });
  });

  test('accepts a reservation and finalizes rider assignment', async () => {
    OrderReservation.findById.mockResolvedValue({
      _id: 'res-1',
      orderId: 'order-1',
      riderId: 'rider-1',
      entityType: 'order',
    });
    prisma.order.findUnique
      .mockResolvedValueOnce({
        id: 'order-1',
        orderNumber: 'ORD-1',
        riderId: null,
        status: 'ready',
        fulfillmentMode: 'delivery',
        isScheduledOrder: false,
        paymentStatus: 'paid',
        totalAmount: 55,
      })
      .mockResolvedValueOnce({
        id: 'order-1',
        orderNumber: 'ORD-1',
        restaurantId: 'rest-1',
        restaurant: { latitude: 5.6, longitude: -0.1 },
      });
    dispatchService.acceptReservation.mockResolvedValue({ success: true });
    prisma.order.update
      .mockResolvedValueOnce({
        id: 'order-1',
        orderNumber: 'ORD-1',
        customerId: 'customer-1',
        riderId: 'rider-1',
        status: 'picked_up',
        restaurantId: 'rest-1',
        restaurant: { latitude: 5.6, longitude: -0.1, averagePreparationTime: 18 },
        deliveryLatitude: 5.7,
        deliveryLongitude: -0.12,
        items: [{ id: 'item-1' }],
        rider: { username: 'Yaw', phone: '233555000111' },
      })
      .mockResolvedValueOnce(undefined);

    const response = await withAuth(
      request(app).post('/api/riders/reservation/res-1/accept')
    );

    expect(response.statusCode).toBe(200);
    expect(response.body).toMatchObject({
      success: true,
      message: 'Order accepted successfully via reservation',
      data: {
        id: 'order-1',
        riderId: 'rider-1',
        status: 'picked_up',
      },
    });
    expect(dispatchService.acceptReservation).toHaveBeenCalledWith('res-1', 'rider-1');
    expect(socketService.emitToUserRoom).toHaveBeenCalledWith(
      'customer-1',
      'order_accepted',
      expect.objectContaining({
        orderId: 'order-1',
        rider: expect.objectContaining({ id: 'rider-1' }),
      })
    );
    expect(socketService.broadcastOrderTaken).toHaveBeenCalledWith('order-1', 'rider-1');
  });

  test('rejects accepting a reservation owned by another rider', async () => {
    OrderReservation.findById.mockResolvedValue({
      _id: 'res-2',
      orderId: 'order-2',
      riderId: 'rider-2',
      entityType: 'order',
    });

    const response = await withAuth(
      request(app).post('/api/riders/reservation/res-2/accept'),
      { role: 'rider', userId: 'rider-1', email: 'rider-1@example.com' }
    );

    expect(response.statusCode).toBe(403);
    expect(response.body).toEqual({
      success: false,
      message: 'This reservation does not belong to you',
    });
  });

  test('declines a reservation and marks retry resolved when redispatch succeeds', async () => {
    dispatchService.declineReservation.mockResolvedValue({
      success: true,
      orderId: 'order-9',
      orderNumber: 'ORD-9',
      nextDispatch: {
        success: true,
        riderId: 'rider-2',
        riderName: 'Ama',
        attemptNumber: 2,
      },
    });

    const response = await withAuth(
      request(app).post('/api/riders/reservation/res-9/decline').send({ reason: 'busy' })
    );

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      message: 'Reservation declined',
      nextDispatch: {
        riderId: 'rider-2',
        riderName: 'Ama',
        attemptNumber: 2,
      },
    });
    expect(dispatchRetryService.markRetryResolved).toHaveBeenCalledWith(
      'order-9',
      'dispatch_succeeded'
    );
  });

  test('directly accepts an order and marks the active reservation as accepted', async () => {
    const activeReservation = {
      _id: 'res-10',
      riderId: 'rider-1',
      status: 'pending',
      save: jest.fn().mockResolvedValue(undefined),
    };
    OrderReservation.findOne.mockResolvedValue(activeReservation);
    prisma.order.findUnique
      .mockResolvedValueOnce({
        id: 'order-10',
        orderNumber: 'ORD-10',
        riderId: null,
        status: 'ready',
        fulfillmentMode: 'delivery',
        isScheduledOrder: false,
        paymentStatus: 'paid',
      })
      .mockResolvedValueOnce({
        id: 'order-10',
        orderNumber: 'ORD-10',
        restaurantId: 'rest-10',
        restaurant: { latitude: 5.6, longitude: -0.1 },
      });
    prisma.order.update
      .mockResolvedValueOnce({
        id: 'order-10',
        orderNumber: 'ORD-10',
        customerId: 'customer-10',
        riderId: 'rider-1',
        status: 'picked_up',
        restaurantId: 'rest-10',
        restaurant: { latitude: 5.6, longitude: -0.1, averagePreparationTime: 18 },
        deliveryLatitude: 5.7,
        deliveryLongitude: -0.12,
        items: [{ id: 'item-1' }],
        rider: { username: 'Yaw', phone: '233555000111' },
      })
      .mockResolvedValueOnce(undefined);

    const response = await withAuth(
      request(app).post('/api/riders/accept-order/order-10')
    );

    expect(response.statusCode).toBe(200);
    expect(response.body).toMatchObject({
      success: true,
      message: 'Order accepted successfully',
      data: {
        id: 'order-10',
        riderId: 'rider-1',
        status: 'picked_up',
      },
    });
    expect(activeReservation.status).toBe('accepted');
    expect(activeReservation.save).toHaveBeenCalled();
    expect(dispatchRetryService.markRetryResolved).toHaveBeenCalledWith(
      'order-10',
      'rider_accepted_order'
    );
  });
});
