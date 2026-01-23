class SocketService {
    constructor() {
        this.io = null;
        this.userSockets = new Map(); // Map userId to socketId
    }

    // Initialize Socket.IO
    initialize(io) {
        this.io = io;
        console.log('✅ Socket service initialized');
    }

    // Store user socket connection
    addUserSocket(userId, socketId) {
        this.userSockets.set(userId.toString(), socketId);
    }

    // Remove user socket connection
    removeUserSocket(userId) {
        this.userSockets.delete(userId.toString());
    }

    // Emit to specific user
    emitToUser(userId, event, data) {
        const socketId = this.userSockets.get(userId.toString());
        if (socketId && this.io) {
            this.io.to(socketId).emit(event, data);
            console.log(`📡 Emitted '${event}' to user ${userId}`);
        } else {
            console.warn(`⚠️  User ${userId} not connected via socket`);
        }
    }

    // Join order tracking room
    joinOrderRoom(socket, orderId) {
        socket.join(`order:${orderId}`);
        console.log(`User joined order room: order:${orderId}`);
    }

    // Leave order tracking room
    leaveOrderRoom(socket, orderId) {
        socket.leave(`order:${orderId}`);
        console.log(`User left order room: order:${orderId}`);
    }

    // Broadcast to order room (all users tracking this order)
    emitToOrder(orderId, event, data) {
        if (this.io) {
            this.io.to(`order:${orderId}`).emit(event, data);
            console.log(`📡 Broadcast '${event}' to order room: order:${orderId}`);
        }
    }

    // Emit to user room (alternative method using rooms)
    emitToUserRoom(userId, event, data) {
        if (this.io) {
            this.io.to(`user:${userId}`).emit(event, data);
            console.log(`📡 Emitted '${event}' to user room: user:${userId}`);
        }
    }
}

module.exports = new SocketService();
