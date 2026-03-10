const { createScopedLogger } = require('../utils/logger');
const console = createScopedLogger('socket_service');

class SocketService {
    constructor() {
        this.io = null;
        this.userSockets = new Map();
        this.riderSockets = new Map();
    }

    initialize(io) {
        this.io = io;
        console.info('socket_service_initialized');
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
        console.info('rider_socket_connected', { riderId, socketId });
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
            console.info('socket_event_emitted_to_user_room', { event, userRoom, connectionCount: room.size });
        } else {
            console.warn('socket_user_room_listener_missing', { userId, event });
        }
    }

    emitToRider(riderId, event, data) {
        const sockets = this.riderSockets.get(riderId.toString());
        if (sockets && sockets.size > 0 && this.io) {
            sockets.forEach(socketId => {
                this.io.to(socketId).emit(event, data);
            });
            console.info('socket_event_emitted_to_rider', { event, riderId, deviceCount: sockets.size });
        } else {
            this.emitToUserRoom(riderId, event, data);
        }
    }

    joinOrderRoom(socket, orderId) {
        socket.join(`order:${orderId}`);
        console.info('socket_joined_order_room', { orderId });
    }

    leaveOrderRoom(socket, orderId) {
        socket.leave(`order:${orderId}`);
        console.info('socket_left_order_room', { orderId });
    }

    emitToOrder(orderId, event, data) {
        if (this.io) {
            this.io.to(`order:${orderId}`).emit(event, data);
            console.info('socket_event_broadcast_to_order_room', { event, orderId });
        }
    }

    emitToUserRoom(userId, event, data) {
        if (this.io) {
            this.io.to(`user:${userId}`).emit(event, data);
            console.info('socket_event_emitted_to_user_room_fallback', { event, userId });
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
        console.info('reservation_notification_sent', {
            riderId,
            reservationId: reservation._id?.toString() || reservation.id,
            orderNumber: reservation.orderNumber,
        });
    }

    notifyReservationCancelled(riderId, reservationId, orderId, reason) {
        const payload = {
            type: 'reservation_cancelled',
            reservationId,
            orderId,
            reason
        };
        
        this.emitToUserRoom(riderId, 'reservation_cancelled', payload);
        console.info('reservation_cancelled_notification_sent', { riderId, reservationId });
    }

    notifyReservationExpired(riderId, reservationId, orderId) {
        const payload = {
            type: 'reservation_expired',
            reservationId,
            orderId
        };
        
        this.emitToUserRoom(riderId, 'reservation_expired', payload);
        console.info('reservation_expired_notification_sent', { riderId, reservationId });
    }

    broadcastOrderTaken(orderId, acceptedByRiderId) {
        if (this.io) {
            this.io.emit('order_taken', {
                orderId,
                acceptedByRiderId,
                timestamp: new Date().toISOString()
            });
            console.info('order_taken_broadcast_sent', { orderId, acceptedByRiderId });
        }
    }
}

module.exports = new SocketService();
