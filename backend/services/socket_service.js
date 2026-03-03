class SocketService {
    constructor() {
        this.io = null;
        this.userSockets = new Map();
        this.riderSockets = new Map();
    }

    initialize(io) {
        this.io = io;
        console.log('✅ Socket service initialized');
    }

    addUserSocket(userId, socketId) {
        this.userSockets.set(userId.toString(), socketId);
    }

    removeUserSocket(userId) {
        this.userSockets.delete(userId.toString());
    }

    addRiderSocket(riderId, socketId) {
        const riderIdStr = riderId.toString();
        if (!this.riderSockets.has(riderIdStr)) {
            this.riderSockets.set(riderIdStr, new Set());
        }
        this.riderSockets.get(riderIdStr).add(socketId);
        console.log(`🚴 Rider ${riderId} connected (socket: ${socketId})`);
    }

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

    isRiderOnline(riderId) {
        const sockets = this.riderSockets.get(riderId.toString());
        return sockets && sockets.size > 0;
    }

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

    emitToRider(riderId, event, data) {
        const sockets = this.riderSockets.get(riderId.toString());
        if (sockets && sockets.size > 0 && this.io) {
            sockets.forEach(socketId => {
                this.io.to(socketId).emit(event, data);
            });
            console.log(`🚴 Emitted '${event}' to rider ${riderId} (${sockets.size} devices)`);
        } else {
            this.emitToUserRoom(riderId, event, data);
        }
    }

    joinOrderRoom(socket, orderId) {
        socket.join(`order:${orderId}`);
        console.log(`User joined order room: order:${orderId}`);
    }

    leaveOrderRoom(socket, orderId) {
        socket.leave(`order:${orderId}`);
        console.log(`User left order room: order:${orderId}`);
    }

    emitToOrder(orderId, event, data) {
        if (this.io) {
            this.io.to(`order:${orderId}`).emit(event, data);
            console.log(`📡 Broadcast '${event}' to order room: order:${orderId}`);
        }
    }

    emitToUserRoom(userId, event, data) {
        if (this.io) {
            this.io.to(`user:${userId}`).emit(event, data);
            console.log(`📡 Emitted '${event}' to user room: user:${userId}`);
        }
    }

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

    notifyReservationExpired(riderId, reservationId, orderId) {
        const payload = {
            type: 'reservation_expired',
            reservationId,
            orderId
        };
        
        this.emitToUserRoom(riderId, 'reservation_expired', payload);
        console.log(`🚴 Sent reservation_expired to rider ${riderId}`);
    }

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
