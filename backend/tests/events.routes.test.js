const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, res, next) => {
    const role = req.header('x-test-role');
    const userId = req.header('x-test-user-id');
    const email = req.header('x-test-email') || 'vendor@test.com';

    if (!role || !userId) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized',
      });
    }

    req.user = { id: userId, role, email };
    return next();
  },
  authorize: (...roles) => (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Required role: ${roles.join(' or ')}`,
      });
    }
    return next();
  },
}));

jest.mock('../services/event_campaign_service', () => {
  class EventCampaignError extends Error {
    constructor(message, { status = 400, code = 'EVENT_CAMPAIGN_ERROR', meta = null } = {}) {
      super(message);
      this.status = status;
      this.code = code;
      this.meta = meta;
    }
  }

  return {
    EventCampaignError,
    createEventCampaign: jest.fn(),
    updateEventCampaign: jest.fn(),
    getActiveEventCampaigns: jest.fn(),
    getEventCampaignDetailBySlug: jest.fn(),
    getEventCampaignVendorsBySlug: jest.fn(),
    getEventCampaignItemsBySlug: jest.fn(),
    getAvailableEventCampaignsForVendor: jest.fn(),
    upsertRestaurantEventParticipation: jest.fn(),
    updateRestaurantEventParticipation: jest.fn(),
    updateFoodEventConfig: jest.fn(),
    listEventParticipants: jest.fn(),
    updateEventParticipantStatus: jest.fn(),
    getEventAudiencePreview: jest.fn(),
    scheduleEventNotifications: jest.fn(),
  };
});

const eventsRoutes = require('../routes/events');
const vendorEventsRoutes = require('../routes/vendor_events');
const adminEventsRoutes = require('../routes/admin_events');
const service = require('../services/event_campaign_service');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/events', eventsRoutes);
  app.use('/api/vendor/events', vendorEventsRoutes);
  app.use('/api/admin/events', adminEventsRoutes);
  return app;
};

const withAuth = (req, role = 'customer', userId = 'user-1', email = 'vendor@test.com') =>
  req.set('x-test-role', role).set('x-test-user-id', userId).set('x-test-email', email);

describe('Events Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('GET /api/events/active returns active campaigns', async () => {
    service.getActiveEventCampaigns.mockResolvedValue([{ id: 'event-1' }]);

    const response = await request(app).get('/api/events/active');

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({ success: true, data: [{ id: 'event-1' }] });
  });

  test('GET /api/events/vendor/available requires restaurant auth', async () => {
    const response = await withAuth(request(app).get('/api/events/vendor/available'), 'customer');

    expect(response.statusCode).toBe(403);
    expect(service.getAvailableEventCampaignsForVendor).not.toHaveBeenCalled();
  });

  test('GET /api/events/vendor/available returns vendor campaigns', async () => {
    service.getAvailableEventCampaignsForVendor.mockResolvedValue([{ id: 'event-1' }]);

    const response = await withAuth(request(app).get('/api/events/vendor/available'), 'restaurant', 'vendor-1');

    expect(response.statusCode).toBe(200);
    expect(service.getAvailableEventCampaignsForVendor).toHaveBeenCalledWith({
      user: expect.objectContaining({ id: 'vendor-1', role: 'restaurant' }),
    });
  });

  test('GET /api/vendor/events/available returns vendor campaigns via alias route', async () => {
    service.getAvailableEventCampaignsForVendor.mockResolvedValue([{ id: 'event-1' }]);

    const response = await withAuth(
      request(app).get('/api/vendor/events/available'),
      'restaurant',
      'vendor-1',
    );

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      data: [{ id: 'event-1' }],
    });
  });

  test('POST /api/events/vendor/:eventId/participation joins campaign', async () => {
    service.upsertRestaurantEventParticipation.mockResolvedValue({ id: 'part-1' });

    const response = await withAuth(
      request(app).post('/api/events/vendor/event-1/participation').send({ supportsPreorder: true }),
      'restaurant',
      'vendor-1',
    );

    expect(response.statusCode).toBe(201);
    expect(response.body.success).toBe(true);
    expect(service.upsertRestaurantEventParticipation).toHaveBeenCalledWith({
      user: expect.objectContaining({ id: 'vendor-1' }),
      eventId: 'event-1',
      supportsPreorder: true,
    });
  });

  test('PATCH /api/events/vendor/foods/:foodId/event-config updates event item config', async () => {
    service.updateFoodEventConfig.mockResolvedValue({ id: 'food-1', isEventItem: true });

    const response = await withAuth(
      request(app)
        .patch('/api/events/vendor/foods/food-1/event-config')
        .send({ eventCampaignId: 'event-1', isEventItem: true }),
      'restaurant',
      'vendor-1',
    );

    expect(response.statusCode).toBe(200);
    expect(service.updateFoodEventConfig).toHaveBeenCalledWith({
      user: expect.objectContaining({ id: 'vendor-1' }),
      foodId: 'food-1',
      data: { eventCampaignId: 'event-1', isEventItem: true },
    });
  });

  test('POST /api/events/admin creates event campaign', async () => {
    service.createEventCampaign.mockResolvedValue({ id: 'event-1' });

    const response = await withAuth(
      request(app).post('/api/events/admin').send({ name: 'Valentine' }),
      'admin',
      'admin-1',
    );

    expect(response.statusCode).toBe(201);
    expect(service.createEventCampaign).toHaveBeenCalledWith({
      data: { name: 'Valentine' },
      createdById: 'admin-1',
    });
  });

  test('POST /api/admin/events creates event campaign via alias route', async () => {
    service.createEventCampaign.mockResolvedValue({ id: 'event-2' });

    const response = await withAuth(
      request(app).post('/api/admin/events').send({ name: 'Christmas' }),
      'admin',
      'admin-1',
    );

    expect(response.statusCode).toBe(201);
    expect(response.body).toEqual({
      success: true,
      data: { id: 'event-2' },
    });
  });

  test('GET /api/admin/events/:id/participants returns event participants via alias route', async () => {
    service.listEventParticipants.mockResolvedValue({
      campaign: { id: 'event-1' },
      participants: [{ restaurantId: 'rest-1' }],
    });

    const response = await withAuth(
      request(app).get('/api/admin/events/event-1/participants'),
      'admin',
      'admin-1',
    );

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      data: {
        campaign: { id: 'event-1' },
        participants: [{ restaurantId: 'rest-1' }],
      },
    });
  });

  test('PATCH /api/admin/events/:id/participants/:restaurantId updates participant via alias route', async () => {
    service.updateEventParticipantStatus.mockResolvedValue({
      eventCampaignId: 'event-1',
      restaurantId: 'rest-1',
      status: 'approved',
    });

    const response = await withAuth(
      request(app)
        .patch('/api/admin/events/event-1/participants/rest-1')
        .send({ action: 'approve', isFeatured: true }),
      'admin',
      'admin-1',
    );

    expect(response.statusCode).toBe(200);
    expect(service.updateEventParticipantStatus).toHaveBeenCalledWith({
      eventId: 'event-1',
      restaurantId: 'rest-1',
      data: { action: 'approve', isFeatured: true },
    });
  });

  test('GET /api/events/admin/:id/audience-preview returns preview', async () => {
    service.getEventAudiencePreview.mockResolvedValue({ stats: { selectedUsers: 4 } });

    const response = await withAuth(
      request(app).get('/api/events/admin/event-1/audience-preview'),
      'admin',
      'admin-1',
    );

    expect(response.statusCode).toBe(200);
    expect(response.body.data.stats.selectedUsers).toBe(4);
  });

  test('POST /api/events/admin/:id/schedule-notifications surfaces typed errors', async () => {
    service.scheduleEventNotifications.mockRejectedValue(
      new service.EventCampaignError('Event campaign not found', {
        status: 404,
        code: 'EVENT_CAMPAIGN_NOT_FOUND',
      }),
    );

    const response = await withAuth(
      request(app).post('/api/events/admin/event-404/schedule-notifications'),
      'admin',
      'admin-1',
    );

    expect(response.statusCode).toBe(404);
    expect(response.body).toEqual({
      success: false,
      message: 'Event campaign not found',
      code: 'EVENT_CAMPAIGN_NOT_FOUND',
    });
  });

  test('GET /api/events/:slug/vendors returns public vendor data', async () => {
    service.getEventCampaignVendorsBySlug.mockResolvedValue({ vendors: [{ id: 'rest-1' }] });

    const response = await request(app)
      .get('/api/events/valentine/vendors')
      .query({ userLat: '5.6', userLng: '-0.2', maxDistance: '10', limit: '5' });

    expect(response.statusCode).toBe(200);
    expect(service.getEventCampaignVendorsBySlug).toHaveBeenCalledWith({
      slug: 'valentine',
      userLat: '5.6',
      userLng: '-0.2',
      maxDistanceKm: '10',
      limit: '5',
    });
  });

  test('GET /api/events/:slug/items returns safe 500 fallback for unexpected errors', async () => {
    service.getEventCampaignItemsBySlug.mockRejectedValue(new Error('db offline'));

    const response = await request(app).get('/api/events/valentine/items');

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Failed to load event items',
    });
  });

  test('GET /api/events/:slug returns event detail', async () => {
    service.getEventCampaignDetailBySlug.mockResolvedValue({ id: 'event-1', slug: 'valentine' });

    const response = await request(app).get('/api/events/valentine');

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      data: { id: 'event-1', slug: 'valentine' },
    });
  });
});
