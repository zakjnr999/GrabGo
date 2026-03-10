/**
 * Socket.IO Singleton
 * 
 * Provides global access to the Socket.IO instance without circular dependencies.
 * The server.js file initializes the io instance, and routes can access it via getIO().
 */
const { createScopedLogger } = require('./logger');
const console = createScopedLogger('socket_singleton');

let io = null;

/**
 * Initialize the Socket.IO instance
 * Called once from server.js after io is created
 */
const initIO = (socketIO) => {
    if (io) {
        console.warn('socket_io_instance_already_initialized');
        return;
    }
    io = socketIO;
    console.info('socket_io_singleton_initialized');
};

/**
 * Get the Socket.IO instance
 * Returns null if not yet initialized
 */
const getIO = () => {
    if (!io) {
        console.warn('socket_io_instance_not_yet_initialized');
    }
    return io;
};

module.exports = { initIO, getIO };
