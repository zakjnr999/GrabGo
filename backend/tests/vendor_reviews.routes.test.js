const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, res, next) => {
    req.user = { id: 'user-1', role: req.header('x-test-role') || 'customer' };
    return next();
  },
  admin: (req, res, next) => {
    if (req.user?.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    return next();
  },
}));

jest.mock('../services/vendor_rating_service', () => {
  class VendorRatingError extends Error {
    constructor(message, { statusCode = 400, code = 'VENDOR_RATING_FAILED' } = {}) {
      super(message);
      this.statusCode = statusCode;
      this.code = code;
    }
  }

  return {
    VendorRatingError,
    getVendorReviews: jest.fn(),
    moderateVendorReview: jest.fn(),
    reportVendorReview: jest.fn(),
  };
});

jest.mock('../utils/metrics', () => ({
  recordReviewEvent: jest.fn(),
}));

jest.mock('../utils/logger', () => ({
  error: jest.fn(),
}));

const {
  VendorRatingError,
  getVendorReviews,
  moderateVendorReview,
  reportVendorReview,
} = require('../services/vendor_rating_service');
const metrics = require('../utils/metrics');
const vendorReviewRoutes = require('../routes/vendor_reviews');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/vendor-reviews', vendorReviewRoutes);
  return app;
};

describe('Vendor Review Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns vendor reviews successfully', async () => {
    getVendorReviews.mockResolvedValue({ reviews: [], total: 0 });

    const response = await request(app).get('/api/vendor-reviews/restaurant/vendor-1');

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
  });

  test('returns typed review business errors', async () => {
    getVendorReviews.mockRejectedValue(
      new VendorRatingError('Unsupported vendor type', {
        statusCode: 400,
        code: 'VENDOR_TYPE_INVALID',
      })
    );

    const response = await request(app).get('/api/vendor-reviews/invalid/vendor-1');

    expect(response.statusCode).toBe(400);
    expect(response.body.code).toBe('VENDOR_TYPE_INVALID');
  });

  test('returns safe 500 for unexpected vendor review fetch failures', async () => {
    getVendorReviews.mockRejectedValue(new Error('db timeout'));

    const response = await request(app).get('/api/vendor-reviews/restaurant/vendor-1');

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
    expect(metrics.recordReviewEvent).toHaveBeenCalledWith({
      reviewType: 'vendor',
      action: 'fetch',
      result: 'failure',
    });
  });

  test('reports a vendor review', async () => {
    reportVendorReview.mockResolvedValue({ reported: true });

    const response = await request(app)
      .post('/api/vendor-reviews/review-1/report')
      .send({ reason: 'spam' });

    expect(response.statusCode).toBe(201);
    expect(response.body.success).toBe(true);
  });

  test('returns safe 500 for unexpected vendor review report failures', async () => {
    reportVendorReview.mockRejectedValue(new Error('insert failed'));

    const response = await request(app)
      .post('/api/vendor-reviews/review-1/report')
      .send({ reason: 'spam' });

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
    expect(metrics.recordReviewEvent).toHaveBeenCalledWith({
      reviewType: 'vendor',
      action: 'report',
      result: 'failure',
    });
  });

  test('moderates a vendor review for admins', async () => {
    moderateVendorReview.mockResolvedValue({ id: 'review-1', isHidden: true });

    const response = await request(app)
      .patch('/api/vendor-reviews/review-1/moderation')
      .set('x-test-role', 'admin')
      .send({ isHidden: true });

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
  });

  test('blocks vendor review moderation for non-admins', async () => {
    const response = await request(app)
      .patch('/api/vendor-reviews/review-1/moderation')
      .send({ isHidden: true });

    expect(response.statusCode).toBe(403);
    expect(response.body).toEqual({
      success: false,
      message: 'Forbidden',
    });
    expect(moderateVendorReview).not.toHaveBeenCalled();
  });
});
