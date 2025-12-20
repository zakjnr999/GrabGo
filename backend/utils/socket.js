/**
 * Socket.IO Singleton
 * 
 * Provides global access to the Socket.IO instance without circular dependencies.
 * The server.js file initializes the io instance, and routes can access it via getIO().
 */

let io = null;

/**
 * Initialize the Socket.IO instance
 * Called once from server.js after io is created
 */
const initIO = (socketIO) => {
    if (io) {
        console.warn('⚠️ Socket.IO instance already initialized');
        return;
    }
    io = socketIO;
    console.log('✅ Socket.IO singleton initialized');
};

/**
 * Get the Socket.IO instance
 * Returns null if not yet initialized
 */
const getIO = () => {
    if (!io) {
        console.warn('⚠️ Socket.IO instance not yet initialized');
    }
    return io;
};

module.exports = { initIO, getIO };
