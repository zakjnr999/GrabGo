/**
 * Integration Tests for Status API Routes
 * 
 * Tests cover:
 * - GET /api/statuses - List statuses
 * - GET /api/statuses/stories - Get stories
 * - POST /api/statuses - Create status
 * - POST /api/statuses/:id/view - Record view
 * - POST /api/statuses/:id/like - Toggle like
 * - POST /api/statuses/views/batch - Batch views
 */

const request = require('supertest');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const express = require('express');

// Models
const Status = require('../models/Status');
const User = require('../models/User');
const Restaurant = require('../models/Restaurant');

// Routes
const statusRoutes = require('../routes/statuses');

// Test configuration
const TEST_DB_URI = process.env.TEST_MONGODB_URI || 'mongodb://localhost:27017/grabgo_test';
const JWT_SECRET = process.env.JWT_SECRET || 'test-secret';

// Create test app
const app = express();
app.use(express.json());
app.use('/api/statuses', statusRoutes);

// Mock data
let testUser;
let testRestaurant;
let testToken;
let adminToken;

describe('Status API Routes', () => {
    beforeAll(async () => {
        await mongoose.connect(TEST_DB_URI);

        // Create test user
        testUser = await User.create({
            name: 'Test User',
            email: 'test@example.com',
            password: 'hashedpassword',
            role: 'customer',
        });

        // Create admin user
        const adminUser = await User.create({
            name: 'Admin User',
            email: 'admin@example.com',
            password: 'hashedpassword',
            role: 'admin',
        });

        // Create test restaurant
        testRestaurant = await Restaurant.create({
            restaurant_name: 'Test Restaurant',
            email: 'restaurant@example.com',
            phone: '1234567890',
            address: '123 Test St',
            status: 'approved',
        });

        // Generate tokens
        testToken = jwt.sign({ id: testUser._id, role: 'customer' }, JWT_SECRET);
        adminToken = jwt.sign({ id: adminUser._id, role: 'admin' }, JWT_SECRET);
    });

    afterAll(async () => {
        await User.deleteMany({});
        await Restaurant.deleteMany({});
        await Status.deleteMany({});
        await mongoose.connection.close();
    });

    beforeEach(async () => {
        await Status.deleteMany({});
    });

    // ============================================================
    // GET /api/statuses
    // ============================================================
    describe('GET /api/statuses', () => {
        beforeEach(async () => {
            await Status.create([
                {
                    restaurant: testRestaurant._id,
                    category: 'daily_special',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image1.jpg',
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
                {
                    restaurant: testRestaurant._id,
                    category: 'discount',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image2.jpg',
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
            ]);
        });

        test('should return all active statuses', async () => {
            const res = await request(app)
                .get('/api/statuses')
                .expect(200);

            expect(res.body.success).toBe(true);
            expect(res.body.data).toHaveLength(2);
        });

        test('should filter by category', async () => {
            const res = await request(app)
                .get('/api/statuses?category=daily_special')
                .expect(200);

            expect(res.body.success).toBe(true);
            expect(res.body.data).toHaveLength(1);
            expect(res.body.data[0].category).toBe('daily_special');
        });

        test('should return pagination info', async () => {
            const res = await request(app)
                .get('/api/statuses?limit=1&page=1')
                .expect(200);

            expect(res.body.pagination).toBeDefined();
            expect(res.body.pagination.currentPage).toBe(1);
            expect(res.body.pagination.totalItems).toBe(2);
        });

        test('should reject invalid category', async () => {
            const res = await request(app)
                .get('/api/statuses?category=invalid')
                .expect(400);

            expect(res.body.success).toBe(false);
        });
    });

    // ============================================================
    // GET /api/statuses/stories
    // ============================================================
    describe('GET /api/statuses/stories', () => {
        beforeEach(async () => {
            await Status.create([
                {
                    restaurant: testRestaurant._id,
                    category: 'daily_special',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image1.jpg',
                    viewCount: 100,
                    likeCount: 50,
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
                {
                    restaurant: testRestaurant._id,
                    category: 'discount',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image2.jpg',
                    viewCount: 200,
                    likeCount: 100,
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
            ]);
        });

        test('should return stories grouped by restaurant', async () => {
            const res = await request(app)
                .get('/api/statuses/stories')
                .expect(200);

            expect(res.body.success).toBe(true);
            expect(res.body.data).toHaveLength(1); // One restaurant
            expect(res.body.data[0].statusCount).toBe(2);
            expect(res.body.data[0].totalViews).toBe(300);
            expect(res.body.data[0].totalLikes).toBe(150);
        });

        test('should sort by engagement when specified', async () => {
            const res = await request(app)
                .get('/api/statuses/stories?sortBy=engagement')
                .expect(200);

            expect(res.body.success).toBe(true);
        });

        test('should respect limit parameter', async () => {
            const res = await request(app)
                .get('/api/statuses/stories?limit=1')
                .expect(200);

            expect(res.body.data.length).toBeLessThanOrEqual(1);
        });
    });

    // ============================================================
    // POST /api/statuses/:id/view
    // ============================================================
    describe('POST /api/statuses/:id/view', () => {
        let testStatus;

        beforeEach(async () => {
            testStatus = await Status.create({
                restaurant: testRestaurant._id,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });
        });

        test('should record a view with duration', async () => {
            const res = await request(app)
                .post(`/api/statuses/${testStatus._id}/view`)
                .set('Authorization', `Bearer ${testToken}`)
                .send({ duration: 5000 })
                .expect(200);

            expect(res.body.success).toBe(true);
            expect(res.body.data.viewCount).toBe(1);
        });

        test('should require authentication', async () => {
            await request(app)
                .post(`/api/statuses/${testStatus._id}/view`)
                .send({ duration: 5000 })
                .expect(401);
        });

        test('should reject invalid status ID', async () => {
            const res = await request(app)
                .post('/api/statuses/invalid-id/view')
                .set('Authorization', `Bearer ${testToken}`)
                .send({ duration: 5000 })
                .expect(400);

            expect(res.body.success).toBe(false);
        });

        test('should reject view on expired status', async () => {
            const expiredStatus = await Status.create({
                restaurant: testRestaurant._id,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/expired.jpg',
                expiresAt: new Date(Date.now() - 1000),
            });

            const res = await request(app)
                .post(`/api/statuses/${expiredStatus._id}/view`)
                .set('Authorization', `Bearer ${testToken}`)
                .send({ duration: 5000 })
                .expect(400);

            expect(res.body.message).toContain('expired');
        });
    });

    // ============================================================
    // POST /api/statuses/:id/like
    // ============================================================
    describe('POST /api/statuses/:id/like', () => {
        let testStatus;

        beforeEach(async () => {
            testStatus = await Status.create({
                restaurant: testRestaurant._id,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });
        });

        test('should like a status', async () => {
            const res = await request(app)
                .post(`/api/statuses/${testStatus._id}/like`)
                .set('Authorization', `Bearer ${testToken}`)
                .expect(200);

            expect(res.body.success).toBe(true);
            expect(res.body.data.isLiked).toBe(true);
            expect(res.body.data.likeCount).toBe(1);
        });

        test('should unlike a status', async () => {
            // First like
            await request(app)
                .post(`/api/statuses/${testStatus._id}/like`)
                .set('Authorization', `Bearer ${testToken}`);

            // Then unlike
            const res = await request(app)
                .post(`/api/statuses/${testStatus._id}/like`)
                .set('Authorization', `Bearer ${testToken}`)
                .expect(200);

            expect(res.body.data.isLiked).toBe(false);
            expect(res.body.data.likeCount).toBe(0);
        });

        test('should require authentication', async () => {
            await request(app)
                .post(`/api/statuses/${testStatus._id}/like`)
                .expect(401);
        });
    });

    // ============================================================
    // POST /api/statuses/views/batch
    // ============================================================
    describe('POST /api/statuses/views/batch', () => {
        let statuses;

        beforeEach(async () => {
            statuses = await Status.create([
                {
                    restaurant: testRestaurant._id,
                    category: 'daily_special',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image1.jpg',
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
                {
                    restaurant: testRestaurant._id,
                    category: 'discount',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image2.jpg',
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
            ]);
        });

        test('should record batch views', async () => {
            const res = await request(app)
                .post('/api/statuses/views/batch')
                .set('Authorization', `Bearer ${testToken}`)
                .send({
                    views: [
                        { statusId: statuses[0]._id.toString(), duration: 3000 },
                        { statusId: statuses[1]._id.toString(), duration: 4000 },
                    ],
                })
                .expect(200);

            expect(res.body.success).toBe(true);
            expect(res.body.data.processed).toBe(2);
            expect(res.body.requestId).toBeDefined(); // Request ID for tracing
        });

        test('should reject empty views array', async () => {
            const res = await request(app)
                .post('/api/statuses/views/batch')
                .set('Authorization', `Bearer ${testToken}`)
                .send({ views: [] })
                .expect(400);

            expect(res.body.success).toBe(false);
        });

        test('should reject more than 20 views', async () => {
            const views = Array(21).fill(null).map((_, i) => ({
                statusId: new mongoose.Types.ObjectId().toString(),
                duration: 1000,
            }));

            const res = await request(app)
                .post('/api/statuses/views/batch')
                .set('Authorization', `Bearer ${testToken}`)
                .send({ views })
                .expect(400);

            expect(res.body.message).toContain('Maximum 20');
        });

        test('should require authentication', async () => {
            await request(app)
                .post('/api/statuses/views/batch')
                .send({ views: [] })
                .expect(401);
        });
    });

    // ============================================================
    // GET /api/statuses/:id
    // ============================================================
    describe('GET /api/statuses/:id', () => {
        let testStatus;

        beforeEach(async () => {
            testStatus = await Status.create({
                restaurant: testRestaurant._id,
                category: 'daily_special',
                title: 'Test Status',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });
        });

        test('should return a single status', async () => {
            const res = await request(app)
                .get(`/api/statuses/${testStatus._id}`)
                .expect(200);

            expect(res.body.success).toBe(true);
            expect(res.body.data.title).toBe('Test Status');
        });

        test('should return 404 for non-existent status', async () => {
            const fakeId = new mongoose.Types.ObjectId();
            const res = await request(app)
                .get(`/api/statuses/${fakeId}`)
                .expect(404);

            expect(res.body.success).toBe(false);
        });

        test('should reject invalid ID format', async () => {
            const res = await request(app)
                .get('/api/statuses/invalid-id')
                .expect(400);

            expect(res.body.success).toBe(false);
        });
    });
});
