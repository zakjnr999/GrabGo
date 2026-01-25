/**
 * Jest Test Setup
 * 
 * This file runs before all tests to set up the test environment.
 */

// Load environment variables
require('dotenv').config({ path: '.env.test' });

// Set test environment
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-jwt-secret-key';

// Increase timeout for database operations
jest.setTimeout(30000);

// Global test utilities
global.testUtils = {
    /**
     * Generate a mock ID (Prisma uses cuid/strings)
     */
    generateObjectId: () => {
        return Math.random().toString(36).substring(2, 15);
    },

    /**
     * Generate a mock JWT token
     */
    generateToken: (userId, role = 'customer') => {
        const jwt = require('jsonwebtoken');
        return jwt.sign(
            { id: userId, role },
            process.env.JWT_SECRET,
            { expiresIn: '1h' }
        );
    },

    /**
     * Wait for a specified duration
     */
    wait: (ms) => new Promise(resolve => setTimeout(resolve, ms)),
};

// Suppress console logs during tests (optional)
if (process.env.SUPPRESS_LOGS === 'true') {
    global.console = {
        ...console,
        log: jest.fn(),
        debug: jest.fn(),
        info: jest.fn(),
        warn: jest.fn(),
        // Keep error for debugging
        error: console.error,
    };
}

// Clean up after all tests
afterAll(async () => {
    // Close Prisma client
    const prisma = require('../config/prisma');
    await prisma.$disconnect();
});
