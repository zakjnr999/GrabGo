class SocketService {
    constructor() {
        this.io = null;
        this.userSockets = new Map(); // Map userId to socketId
        this.riderSockets = new Map(); // Map riderId to Set of socketIds (rider can have multiple connections)
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

    // Store rider socket connection (supports multiple devices)
    addRiderSocket(riderId, socketId) {
        const riderIdStr = riderId.toString();
        if (!this.riderSockets.has(riderIdStr)) {
            this.riderSockets.set(riderIdStr, new Set());
        }
        this.riderSockets.get(riderIdStr).add(socketId);
        console.log(`🚴 Rider ${riderId} connected (socket: ${socketId})`);
    }

    // Remove rider socket connection
    removeRiderSocket(riderId, socketId) {
        const riderIdStr = riderId.toString();
        const sockets = this.riderSockets.get(riderIdStr);
        if (sockets) {
            sockets.delete(socketId);
            if (sockets.size === 0) {
                this.riderSockets.delete(riderIdStr);
            }
        }
    }

    // Check if rider is connected
    isRiderOnline(riderId) {
        const sockets = this.riderSockets.get(riderId.toString());
        return sockets && sockets.size > 0;
    }

    // Emit to specific user
    emitToUser(userId, event, data) {
        if (!this.io) return;

        const userRoom = `user:${userId.toString()}`;
        this.io.to(userRoom).emit(event, data);

        const room = this.io.sockets?.adapter?.rooms?.get(userRoom);
        if (room && room.size > 0) {
            console.log(`📡 Emitted '${event}' to user room: ${userRoom} (${room.size} connections)`);
        } else {
            console.warn(`⚠️  User ${userId} has no active socket room listeners for '${event}'`);
        }
    }

    // Emit to rider (all connected devices)
    emitToRider(riderId, event, data) {
        const sockets = this.riderSockets.get(riderId.toString());
        if (sockets && sockets.size > 0 && this.io) {
            sockets.forEach(socketId => {
                this.io.to(socketId).emit(event, data);
            });
            console.log(`🚴 Emitted '${event}' to rider ${riderId} (${sockets.size} devices)`);
        } else {
            // Fallback to user room
            this.emitToUserRoom(riderId, event, data);
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

    // ==================== ORDER RESERVATION EVENTS ====================

    /**
     * Notify rider of a new order reservation
     * @param {string} riderId - Rider ID
     * @param {Object} reservation - Reservation object with order details
     */
    notifyOrderReserved(riderId, reservation) {
        const payload = {
            type: 'order_reserved',
            reservationId: reservation._id?.toString() || reservation.id,
            orderId: reservation.orderId,
            orderNumber: reservation.orderNumber,
            expiresAt: reservation.expiresAt,
            timeoutMs: reservation.timeoutMs,
            attemptNumber: reservation.attemptNumber,
            estimatedEarnings: reservation.estimatedEarnings,
            distanceToPickup: reservation.distanceToPickup,
            order: reservation.orderSnapshot
        };
        
        this.emitToUserRoom(riderId, 'order_reserved', payload);
        console.log(`🚴 Sent order_reserved to rider ${riderId} for order ${reservation.orderNumber}`);
    }

    /**
     * Notify rider that their reservation was cancelled
     * @param {string} riderId - Rider ID
     * @param {string} reservationId - Reservation ID
     * @param {string} orderId - Order ID
     * @param {string} reason - Cancellation reason
     */
    notifyReservationCancelled(riderId, reservationId, orderId, reason) {
        const payload = {
            type: 'reservation_cancelled',
            reservationId,
            orderId,
            reason
        };
        
        this.emitToUserRoom(riderId, 'reservation_cancelled', payload);
        console.log(`🚴 Sent reservation_cancelled to rider ${riderId}`);
    }

    /**
     * Notify rider that their reservation expired
     * @param {string} riderId - Rider ID
     * @param {string} reservationId - Reservation ID
     * @param {string} orderId - Order ID
     */
    notifyReservationExpired(riderId, reservationId, orderId) {
        const payload = {
            type: 'reservation_expired',
            reservationId,
            orderId
        };
        
        this.emitToUserRoom(riderId, 'reservation_expired', payload);
        console.log(`🚴 Sent reservation_expired to rider ${riderId}`);
    }

    /**
     * Broadcast to all online riders that an order was taken
     * (So they can remove it from their UI if they were viewing available orders)
     * @param {string} orderId - Order ID
     * @param {string} acceptedByRiderId - Rider who accepted
     */
    broadcastOrderTaken(orderId, acceptedByRiderId) {
        if (this.io) {
            this.io.emit('order_taken', {
                orderId,
                acceptedByRiderId,
                timestamp: new Date().toISOString()
            });
            console.log(`📢 Broadcast order_taken for order ${orderId}`);
        }
    }
}

module.exports = new SocketService();
