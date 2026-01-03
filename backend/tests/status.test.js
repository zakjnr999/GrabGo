/**
 * Unit Tests for Status Feature
 * 
 * Tests cover:
 * - Status creation
 * - View recording (single and batch)
 * - Like/unlike functionality
 * - Cache invalidation
 * - Engagement score calculation
 * - Status expiration
 */

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const Status = require('../models/Status');

// Mock data
const mockUserId = new mongoose.Types.ObjectId();
const mockRestaurantId = new mongoose.Types.ObjectId();
const mockFoodId = new mongoose.Types.ObjectId();

let mongoServer;

describe('Status Model', () => {
    beforeAll(async () => {
        mongoServer = await MongoMemoryServer.create();
        const mongoUri = mongoServer.getUri();
        await mongoose.connect(mongoUri);
    }, 60000);

    afterAll(async () => {
        await mongoose.connection.dropDatabase();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    beforeEach(async () => {
        await Status.deleteMany({});
    });

    // ============================================================
    // Status Creation Tests
    // ============================================================
    describe('Status Creation', () => {
        test('should create a status with required fields', async () => {
            const statusData = {
                restaurant: mockRestaurantId,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
            };

            const status = await Status.create(statusData);

            expect(status).toBeDefined();
            expect(status.restaurant.toString()).toBe(mockRestaurantId.toString());
            expect(status.category).toBe('daily_special');
            expect(status.mediaType).toBe('image');
            expect(status.isActive).toBe(true);
            expect(status.viewCount).toBe(0);
            expect(status.likeCount).toBe(0);
            expect(status.engagementScore).toBe(0);
        });

        test('should create a status with all optional fields', async () => {
            const statusData = {
                restaurant: mockRestaurantId,
                category: 'discount',
                title: 'Special Offer',
                description: '50% off all items',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                thumbnailUrl: 'https://example.com/thumb.jpg',
                blurHash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
                discountPercentage: 50,
                promoCode: 'SAVE50',
                linkedFood: mockFoodId,
                isRecommended: true,
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            };

            const status = await Status.create(statusData);

            expect(status.title).toBe('Special Offer');
            expect(status.description).toBe('50% off all items');
            expect(status.discountPercentage).toBe(50);
            expect(status.promoCode).toBe('SAVE50');
            expect(status.isRecommended).toBe(true);
        });

        test('should fail to create status without required fields', async () => {
            const statusData = {
                category: 'daily_special',
            };

            await expect(Status.create(statusData)).rejects.toThrow();
        });

        test('should fail with invalid category', async () => {
            const statusData = {
                restaurant: mockRestaurantId,
                category: 'invalid_category',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            };

            await expect(Status.create(statusData)).rejects.toThrow();
        });

        test('should validate discount percentage range', async () => {
            const statusData = {
                restaurant: mockRestaurantId,
                category: 'discount',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                discountPercentage: 150, // Invalid: > 100
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            };

            await expect(Status.create(statusData)).rejects.toThrow();
        });
    });

    // ============================================================
    // View Recording Tests
    // ============================================================
    describe('View Recording', () => {
        let status;

        beforeEach(async () => {
            status = await Status.create({
                restaurant: mockRestaurantId,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });
        });

        test('should record a new view', async () => {
            await status.recordView(mockUserId, 5000);

            expect(status.viewCount).toBe(1);
            expect(status.viewedBy).toHaveLength(1);
            expect(status.viewedBy[0].user.toString()).toBe(mockUserId.toString());
            expect(status.viewedBy[0].duration).toBe(5000);
        });

        test('should update existing view duration', async () => {
            await status.recordView(mockUserId, 3000);
            await status.recordView(mockUserId, 2000);

            expect(status.viewCount).toBe(1); // Still 1 view
            expect(status.viewedBy).toHaveLength(1);
            expect(status.viewedBy[0].duration).toBe(5000); // 3000 + 2000
        });

        test('should track multiple users views', async () => {
            const user2 = new mongoose.Types.ObjectId();
            const user3 = new mongoose.Types.ObjectId();

            await status.recordView(mockUserId, 3000);
            await status.recordView(user2, 4000);
            await status.recordView(user3, 5000);

            expect(status.viewCount).toBe(3);
            expect(status.viewedBy).toHaveLength(3);
        });

        test('should calculate average view duration', async () => {
            const user2 = new mongoose.Types.ObjectId();

            await status.recordView(mockUserId, 4000);
            await status.recordView(user2, 6000);

            expect(status.avgViewDuration).toBe(5000); // (4000 + 6000) / 2
        });

        test('should update engagement score after view', async () => {
            await status.recordView(mockUserId, 10000);

            // Score = views + (likes * 2) + (avgDuration in seconds / 10)
            // Score = 1 + 0 + (10 / 10) = 2
            expect(status.engagementScore).toBe(2);
        });
    });

    // ============================================================
    // Batch View Recording Tests
    // ============================================================
    describe('Batch View Recording', () => {
        let statuses;

        beforeEach(async () => {
            statuses = await Status.create([
                {
                    restaurant: mockRestaurantId,
                    category: 'daily_special',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image1.jpg',
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
                {
                    restaurant: mockRestaurantId,
                    category: 'discount',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image2.jpg',
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
                {
                    restaurant: mockRestaurantId,
                    category: 'new_item',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image3.jpg',
                    expiresAt: new Date(Date.now() - 1000), // Expired
                },
            ]);
        });

        test('should record batch views for multiple statuses', async () => {
            const views = [
                { statusId: statuses[0]._id.toString(), duration: 3000 },
                { statusId: statuses[1]._id.toString(), duration: 4000 },
            ];

            const results = await Status.recordBatchViews(mockUserId, views);

            expect(results).toHaveLength(2);
            expect(results[0].success).toBe(true);
            expect(results[1].success).toBe(true);

            // Verify in database
            const updated1 = await Status.findById(statuses[0]._id);
            const updated2 = await Status.findById(statuses[1]._id);

            expect(updated1.viewCount).toBe(1);
            expect(updated2.viewCount).toBe(1);
        });

        test('should handle expired status in batch', async () => {
            const views = [
                { statusId: statuses[0]._id.toString(), duration: 3000 },
                { statusId: statuses[2]._id.toString(), duration: 4000 }, // Expired
            ];

            const results = await Status.recordBatchViews(mockUserId, views);

            expect(results[0].success).toBe(true);
            expect(results[1].success).toBe(false);
            expect(results[1].reason).toBe('Status expired');
        });

        test('should handle non-existent status in batch', async () => {
            const fakeId = new mongoose.Types.ObjectId();
            const views = [
                { statusId: statuses[0]._id.toString(), duration: 3000 },
                { statusId: fakeId.toString(), duration: 4000 },
            ];

            const results = await Status.recordBatchViews(mockUserId, views);

            expect(results[0].success).toBe(true);
            expect(results[1].success).toBe(false);
            expect(results[1].reason).toBe('Status not found');
        });
    });

    // ============================================================
    // Like/Unlike Tests
    // ============================================================
    describe('Like/Unlike Functionality', () => {
        let status;

        beforeEach(async () => {
            status = await Status.create({
                restaurant: mockRestaurantId,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });
        });

        test('should like a status', async () => {
            const result = await status.toggleLike(mockUserId);

            expect(result.isLiked).toBe(true);
            expect(result.likeCount).toBe(1);
            expect(status.likedBy).toContainEqual(mockUserId);
        });

        test('should unlike a status', async () => {
            // First like
            await status.toggleLike(mockUserId);
            // Then unlike
            const result = await status.toggleLike(mockUserId);

            expect(result.isLiked).toBe(false);
            expect(result.likeCount).toBe(0);
            expect(status.likedBy).not.toContainEqual(mockUserId);
        });

        test('should track multiple users likes', async () => {
            const user2 = new mongoose.Types.ObjectId();
            const user3 = new mongoose.Types.ObjectId();

            await status.toggleLike(mockUserId);
            await status.toggleLike(user2);
            await status.toggleLike(user3);

            expect(status.likeCount).toBe(3);
            expect(status.likedBy).toHaveLength(3);
        });

        test('should update engagement score after like', async () => {
            await status.toggleLike(mockUserId);

            // Score = views + (likes * 2) + (avgDuration in seconds / 10)
            // Score = 0 + (1 * 2) + 0 = 2
            expect(status.engagementScore).toBe(2);
        });

        test('should not go below 0 likes', async () => {
            // Try to unlike without liking first (edge case)
            status.likedBy = [];
            status.likeCount = 0;
            await status.save();

            // This should handle gracefully
            const result = await status.toggleLike(mockUserId);
            expect(result.isLiked).toBe(true);
            expect(result.likeCount).toBe(1);
        });
    });

    // ============================================================
    // Engagement Score Tests
    // ============================================================
    describe('Engagement Score Calculation', () => {
        let status;

        beforeEach(async () => {
            status = await Status.create({
                restaurant: mockRestaurantId,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });
        });

        test('should calculate correct engagement score', async () => {
            const user2 = new mongoose.Types.ObjectId();

            // 2 views with 10s average duration
            await status.recordView(mockUserId, 10000);
            await status.recordView(user2, 10000);

            // 1 like
            await status.toggleLike(mockUserId);

            // Score = views + (likes * 2) + (avgDuration in seconds / 10)
            // Score = 2 + (1 * 2) + (10 / 10) = 2 + 2 + 1 = 5
            expect(status.engagementScore).toBe(5);
        });
    });

    // ============================================================
    // Status Expiration Tests
    // ============================================================
    describe('Status Expiration', () => {
        test('should identify expired status via virtual', async () => {
            const expiredStatus = await Status.create({
                restaurant: mockRestaurantId,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() - 1000), // Expired
            });

            expect(expiredStatus.isExpired).toBe(true);
        });

        test('should identify active status via virtual', async () => {
            const activeStatus = await Status.create({
                restaurant: mockRestaurantId,
                category: 'daily_special',
                mediaType: 'image',
                mediaUrl: 'https://example.com/image.jpg',
                expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            });

            expect(activeStatus.isExpired).toBe(false);
        });

        test('should cleanup expired statuses', async () => {
            // Create mix of active and expired
            await Status.create([
                {
                    restaurant: mockRestaurantId,
                    category: 'daily_special',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/active.jpg',
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
                {
                    restaurant: mockRestaurantId,
                    category: 'discount',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/expired1.jpg',
                    expiresAt: new Date(Date.now() - 1000),
                },
                {
                    restaurant: mockRestaurantId,
                    category: 'new_item',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/expired2.jpg',
                    expiresAt: new Date(Date.now() - 2000),
                },
            ]);

            const result = await Status.cleanupExpired();

            expect(result.statusesDeactivated).toBe(2);

            // Verify active status is still active
            const activeStatuses = await Status.find({ isActive: true });
            expect(activeStatuses).toHaveLength(1);
        });
    });

    // ============================================================
    // Static Methods Tests
    // ============================================================
    describe('Static Methods', () => {
        beforeEach(async () => {
            await Status.create([
                {
                    restaurant: mockRestaurantId,
                    category: 'daily_special',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image1.jpg',
                    isActive: true,
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
                {
                    restaurant: mockRestaurantId,
                    category: 'discount',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image2.jpg',
                    isActive: false, // Inactive
                    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
                },
                {
                    restaurant: mockRestaurantId,
                    category: 'new_item',
                    mediaType: 'image',
                    mediaUrl: 'https://example.com/image3.jpg',
                    isActive: true,
                    expiresAt: new Date(Date.now() - 1000), // Expired
                },
            ]);
        });

        test('should get only active statuses', async () => {
            const activeStatuses = await Status.getActiveStatuses();

            expect(activeStatuses).toHaveLength(1);
            expect(activeStatuses[0].category).toBe('daily_special');
        });

        test('should filter active statuses by category', async () => {
            const discountStatuses = await Status.getActiveStatuses({ category: 'discount' });

            expect(discountStatuses).toHaveLength(0); // The discount one is inactive
        });
    });
});
