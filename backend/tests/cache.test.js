/**
 * Unit Tests for Cache Utility
 * 
 * Tests cover:
 * - Cache get/set operations
 * - Cache invalidation
 * - TTL expiration
 * - Pattern-based deletion
 * - Fallback to memory cache
 */

const cache = require('../utils/cache');

describe('Cache Utility', () => {
    beforeEach(async () => {
        // Clear all cache before each test
        await cache.flushAll();
    });

    afterAll(async () => {
        await cache.close();
    });

    // ============================================================
    // Basic Cache Operations
    // ============================================================
    describe('Basic Operations', () => {
        test('should set and get a value', async () => {
            const key = 'test:key';
            const value = { foo: 'bar', count: 42 };

            await cache.set(key, value);
            const retrieved = await cache.get(key);

            expect(retrieved).toEqual(value);
        });

        test('should return null for non-existent key', async () => {
            const result = await cache.get('non:existent:key');
            expect(result).toBeNull();
        });

        test('should overwrite existing value', async () => {
            const key = 'test:overwrite';

            await cache.set(key, { version: 1 });
            await cache.set(key, { version: 2 });

            const result = await cache.get(key);
            expect(result.version).toBe(2);
        });

        test('should handle complex nested objects', async () => {
            const key = 'test:complex';
            const value = {
                stories: [
                    { id: '1', name: 'Story 1', views: 100 },
                    { id: '2', name: 'Story 2', views: 200 },
                ],
                metadata: {
                    cached: true,
                    timestamp: Date.now(),
                },
            };

            await cache.set(key, value);
            const retrieved = await cache.get(key);

            expect(retrieved).toEqual(value);
            expect(retrieved.stories).toHaveLength(2);
        });

        test('should handle arrays', async () => {
            const key = 'test:array';
            const value = [1, 2, 3, 'four', { five: 5 }];

            await cache.set(key, value);
            const retrieved = await cache.get(key);

            expect(retrieved).toEqual(value);
        });
    });

    // ============================================================
    // Cache Deletion
    // ============================================================
    describe('Cache Deletion', () => {
        test('should delete a single key', async () => {
            const key = 'test:delete';
            await cache.set(key, 'value');

            await cache.del(key);

            const result = await cache.get(key);
            expect(result).toBeNull();
        });

        test('should handle deleting non-existent key', async () => {
            const result = await cache.del('non:existent');
            expect(result).toBe(true); // Should not throw
        });
    });

    // ============================================================
    // Pattern-Based Deletion (Cache Invalidation)
    // ============================================================
    describe('Pattern-Based Deletion', () => {
        beforeEach(async () => {
            // Set up test data
            await cache.set('grabgo:stories:recent_20', { data: 'stories1' });
            await cache.set('grabgo:stories:engagement_20', { data: 'stories2' });
            await cache.set('grabgo:stories:recent_50', { data: 'stories3' });
            await cache.set('grabgo:status:123', { data: 'status1' });
            await cache.set('grabgo:status:456', { data: 'status2' });
            await cache.set('other:key', { data: 'other' });
        });

        test('should delete keys matching pattern', async () => {
            const deleted = await cache.delByPattern('grabgo:stories:*');

            expect(deleted).toBe(3);

            // Verify stories are deleted
            expect(await cache.get('grabgo:stories:recent_20')).toBeNull();
            expect(await cache.get('grabgo:stories:engagement_20')).toBeNull();
            expect(await cache.get('grabgo:stories:recent_50')).toBeNull();

            // Verify other keys are not deleted
            expect(await cache.get('grabgo:status:123')).not.toBeNull();
            expect(await cache.get('other:key')).not.toBeNull();
        });

        test('should delete status cache keys', async () => {
            const deleted = await cache.delByPattern('grabgo:status:*');

            expect(deleted).toBe(2);
            expect(await cache.get('grabgo:status:123')).toBeNull();
            expect(await cache.get('grabgo:status:456')).toBeNull();
        });

        test('should return 0 for non-matching pattern', async () => {
            const deleted = await cache.delByPattern('nonexistent:*');
            expect(deleted).toBe(0);
        });
    });

    // ============================================================
    // TTL (Time To Live) Tests
    // ============================================================
    describe('TTL Expiration', () => {
        test('should expire key after TTL', async () => {
            const key = 'test:ttl';
            const ttl = 1; // 1 second

            await cache.set(key, 'value', ttl);

            // Should exist immediately
            expect(await cache.get(key)).toBe('value');

            // Wait for expiration
            await new Promise(resolve => setTimeout(resolve, 1500));

            // Should be expired
            expect(await cache.get(key)).toBeNull();
        }, 5000); // Increase timeout for this test

        test('should use default TTL when not specified', async () => {
            const key = 'test:default-ttl';
            await cache.set(key, 'value');

            // Should exist (default TTL is 60 seconds)
            expect(await cache.get(key)).toBe('value');
        });
    });

    // ============================================================
    // Cache Key Generation
    // ============================================================
    describe('Cache Key Generation', () => {
        test('should generate correct cache key', () => {
            const key = cache.makeKey(cache.CACHE_KEYS.STORIES, 'recent_20');
            expect(key).toBe('grabgo:stories:recent_20');
        });

        test('should generate status cache key', () => {
            const key = cache.makeKey(cache.CACHE_KEYS.STATUS, '123abc');
            expect(key).toBe('grabgo:status:123abc');
        });
    });

    // ============================================================
    // Flush All
    // ============================================================
    describe('Flush All', () => {
        test('should clear all grabgo keys', async () => {
            await cache.set('grabgo:test1', 'value1');
            await cache.set('grabgo:test2', 'value2');
            await cache.set('grabgo:stories:test', 'value3');

            await cache.flushAll();

            expect(await cache.get('grabgo:test1')).toBeNull();
            expect(await cache.get('grabgo:test2')).toBeNull();
            expect(await cache.get('grabgo:stories:test')).toBeNull();
        });
    });

    // ============================================================
    // Cache Stats
    // ============================================================
    describe('Cache Stats', () => {
        test('should return cache stats', () => {
            const stats = cache.getStats();

            expect(stats).toBeDefined();
            expect(stats.type).toBeDefined();
            expect(['redis', 'memory']).toContain(stats.type);
        });
    });

    // ============================================================
    // Error Handling
    // ============================================================
    describe('Error Handling', () => {
        test('should handle invalid JSON gracefully', async () => {
            // This tests the fallback behavior
            const result = await cache.get('invalid:key');
            expect(result).toBeNull();
        });
    });
});

// ============================================================
// Integration Tests for Cache Invalidation in Status Routes
// ============================================================
describe('Cache Invalidation Integration', () => {
    beforeEach(async () => {
        await cache.flushAll();
    });

    test('should invalidate stories cache after status creation', async () => {
        // Simulate cached stories
        const cacheKey = cache.makeKey(cache.CACHE_KEYS.STORIES, 'recent_20');
        await cache.set(cacheKey, [{ id: '1', name: 'Old Story' }]);

        // Verify cache exists
        expect(await cache.get(cacheKey)).not.toBeNull();

        // Simulate cache invalidation (as done in status creation)
        await cache.delByPattern('grabgo:stories:*');

        // Verify cache is cleared
        expect(await cache.get(cacheKey)).toBeNull();
    });

    test('should invalidate stories cache after status update', async () => {
        // Set up multiple cache entries
        await cache.set(cache.makeKey(cache.CACHE_KEYS.STORIES, 'recent_20'), { data: 1 });
        await cache.set(cache.makeKey(cache.CACHE_KEYS.STORIES, 'engagement_20'), { data: 2 });

        // Simulate cache invalidation
        const deleted = await cache.delByPattern('grabgo:stories:*');

        expect(deleted).toBe(2);
    });

    test('should invalidate stories cache after status deletion', async () => {
        await cache.set(cache.makeKey(cache.CACHE_KEYS.STORIES, 'recent_50'), { data: 'test' });

        await cache.delByPattern('grabgo:stories:*');

        expect(await cache.get(cache.makeKey(cache.CACHE_KEYS.STORIES, 'recent_50'))).toBeNull();
    });
});
