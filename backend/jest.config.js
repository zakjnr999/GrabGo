/**
 * Jest Configuration for GrabGo Backend Tests
 */

module.exports = {
    // Test environment
    testEnvironment: 'node',

    // Test file patterns
    testMatch: [
        '**/tests/**/*.test.js',
        '**/__tests__/**/*.js',
    ],

    // Files to ignore
    testPathIgnorePatterns: [
        '/node_modules/',
    ],

    // Coverage configuration
    collectCoverageFrom: [
        'models/**/*.js',
        'routes/**/*.js',
        'utils/**/*.js',
        'middleware/**/*.js',
        '!**/node_modules/**',
    ],

    // Coverage thresholds
    coverageThreshold: {
        global: {
            branches: 70,
            functions: 70,
            lines: 70,
            statements: 70,
        },
    },

    // Setup files
    setupFilesAfterEnv: ['./tests/setup.js'],

    // Timeout for tests (increased for MongoDB Memory Server startup)
    testTimeout: 60000,

    // Verbose output
    verbose: true,

    // Force exit after tests complete
    forceExit: true,

    // Detect open handles
    detectOpenHandles: true,
};
