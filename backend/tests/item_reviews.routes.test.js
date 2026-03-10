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

jest.mock('../services/item_review_service', () => {
  class ItemReviewError extends Error {
    constructor(message, { statusCode = 400, code = 'ITEM_REVIEW_FAILED' } = {}) {
      super(message);
      this.statusCode = statusCode;
      this.code = code;
    }
  }

  return {
    ItemReviewError,
    getItemReviews: jest.fn(),
    moderateItemReview: jest.fn(),
    reportItemReview: jest.fn(),
  };
});

jest.mock('../utils/metrics', () => ({
  recordReviewEvent: jest.fn(),
}));

jest.mock('../utils/logger', () => ({
  error: jest.fn(),
}));

const {
  ItemReviewError,
  getItemReviews,
  moderateItemReview,
  reportItemReview,
} = require('../services/item_review_service');
const metrics = require('../utils/metrics');
const itemReviewRoutes = require('../routes/item_reviews');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/item-reviews', itemReviewRoutes);
  return app;
};

describe('Item Review Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns item reviews successfully', async () => {
    getItemReviews.mockResolvedValue({ reviews: [], total: 0 });

    const response = await request(app).get('/api/item-reviews/food/item-1');

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
  });

  test('returns typed item review errors', async () => {
    getItemReviews.mockRejectedValue(
      new ItemReviewError('Unsupported item type', {
        statusCode: 400,
        code: 'ITEM_TYPE_INVALID',
      })
    );

    const response = await request(app).get('/api/item-reviews/invalid/item-1');

    expect(response.statusCode).toBe(400);
    expect(response.body.code).toBe('ITEM_TYPE_INVALID');
  });

  test('returns safe 500 for unexpected item review fetch failures', async () => {
    getItemReviews.mockRejectedValue(new Error('db timeout'));

    const response = await request(app).get('/api/item-reviews/food/item-1');

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
    expect(metrics.recordReviewEvent).toHaveBeenCalledWith({
      reviewType: 'item',
      action: 'fetch',
      result: 'failure',
    });
  });

  test('reports an item review', async () => {
    reportItemReview.mockResolvedValue({ reported: true });

    const response = await request(app)
      .post('/api/item-reviews/review-1/report')
      .send({ reason: 'spam' });

    expect(response.statusCode).toBe(201);
    expect(response.body.success).toBe(true);
  });

  test('returns safe 500 for unexpected item review report failures', async () => {
    reportItemReview.mockRejectedValue(new Error('insert failed'));

    const response = await request(app)
      .post('/api/item-reviews/review-1/report')
      .send({ reason: 'spam' });

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
    expect(metrics.recordReviewEvent).toHaveBeenCalledWith({
      reviewType: 'item',
      action: 'report',
      result: 'failure',
    });
  });

  test('moderates an item review for admins', async () => {
    moderateItemReview.mockResolvedValue({ id: 'review-1', isHidden: true });

    const response = await request(app)
      .patch('/api/item-reviews/review-1/moderation')
      .set('x-test-role', 'admin')
      .send({ isHidden: true });

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
  });

  test('blocks item review moderation for non-admins', async () => {
    const response = await request(app)
      .patch('/api/item-reviews/review-1/moderation')
      .send({ isHidden: true });

    expect(response.statusCode).toBe(403);
    expect(response.body).toEqual({
      success: false,
      message: 'Forbidden',
    });
    expect(moderateItemReview).not.toHaveBeenCalled();
  });
});
