const { randomUUID } = require('crypto');
const { sendCallNotification } = require('./fcm_service');
const cache = require('../utils/cache');
const prisma = require('../config/prisma');

const TERMINAL_ORDER_STATUSES = new Set(['delivered', 'cancelled']);
const VOICE_CALL_TYPE = 'audio';
const ACTIVE_CALL_TTL_SECONDS = 60 * 60; // Keep state long enough for active calls
const USER_SOCKET_TTL_SECONDS = 60 * 60;
const RING_TIMEOUT_MS = 30 * 1000;

class WebRTCSignalingService {
    constructor(io) {
        this.io = io;
        this.activeCalls = new Map();
        this.userSockets = new Map();
        this.userActiveCalls = new Map();
        this.callTimeouts = new Map();
        this.setupSignaling();

        console.log(`[WebRTC] Using ${this._isRedisAvailable() ? 'Redis' : 'in-memory Map'} for call state`);
    }

    _isRedisAvailable() {
        return cache.isRedisConnected();
    }

    setupSignaling() {
        this.io.on('connection', (socket) => {
            console.log(`WebRTC: User connected: ${socket.id}`);

            socket.on('webrtc:register', async (requestedUserId) => {
                try {
                    await this.handleRegister(socket, requestedUserId);
                } catch (error) {
                    console.error('WebRTC register error:', error);
                    this.emitError(socket, 'Failed to register call signaling', 'REGISTER_FAILED');
                }
            });

            socket.on('webrtc:call', async (data) => {
                try {
                    await this.handleCallInitiation(socket, data);
                } catch (error) {
                    console.error('WebRTC call initiation error:', error);
                    this.emitError(socket, 'Unable to start call', 'CALL_INIT_FAILED');
                }
            });

            socket.on('webrtc:answer', async (data) => {
                try {
                    await this.handleCallAnswer(socket, data);
                } catch (error) {
                    console.error('WebRTC call answer error:', error);
                    this.emitError(socket, 'Unable to answer call', 'CALL_ANSWER_FAILED');
                }
            });

            socket.on('webrtc:ice-candidate', async (data) => {
                try {
                    await this.handleIceCandidate(socket, data);
                } catch (error) {
                    console.error('WebRTC ICE candidate error:', error);
                    this.emitError(socket, 'Unable to exchange ICE candidate', 'ICE_CANDIDATE_FAILED');
                }
            });

            socket.on('webrtc:end-call', async (data) => {
                try {
                    await this.handleEndCall(socket, data);
                } catch (error) {
                    console.error('WebRTC end call error:', error);
                    this.emitError(socket, 'Unable to end call', 'END_CALL_FAILED');
                }
            });

            socket.on('webrtc:reject', async (data) => {
                try {
                    await this.handleRejectCall(socket, data);
                } catch (error) {
                    console.error('WebRTC reject call error:', error);
                    this.emitError(socket, 'Unable to reject call', 'REJECT_CALL_FAILED');
                }
            });

            socket.on('disconnect', async () => {
                try {
                    await this.handleDisconnect(socket);
                } catch (error) {
                    console.error('WebRTC disconnect error:', error);
                }
            });
        });
    }

    emitError(socket, message, code, extra = {}) {
        if (!socket || typeof socket.emit !== 'function') return;
        socket.emit('webrtc:error', {
            error: message,
            code,
            ...extra,
        });
    }

    getSocketUserId(socket) {
        return socket?.data?.userId || socket?.userId || null;
    }

    isValidSessionDescription(sessionDescription) {
        if (!sessionDescription || typeof sessionDescription !== 'object') return false;
        if (typeof sessionDescription.sdp !== 'string' || !sessionDescription.sdp.trim()) return false;
        if (typeof sessionDescription.type !== 'string' || !sessionDescription.type.trim()) return false;
        return true;
    }

    isValidIceCandidate(candidate) {
        if (!candidate || typeof candidate !== 'object') return false;
        return typeof candidate.candidate === 'string' && candidate.candidate.trim().length > 0;
    }

    generateCallId() {
        return `call_${Date.now()}_${randomUUID().slice(0, 8)}`;
    }

    setCallTimeout(callId) {
        this.clearCallTimeout(callId);
        const timeoutHandle = setTimeout(() => {
            this.handleCallTimeout(callId).catch((error) => {
                console.error(`WebRTC: Failed to process call timeout for ${callId}:`, error);
            });
        }, RING_TIMEOUT_MS);

        this.callTimeouts.set(callId, timeoutHandle);
    }

    clearCallTimeout(callId) {
        const timeoutHandle = this.callTimeouts.get(callId);
        if (timeoutHandle) {
            clearTimeout(timeoutHandle);
            this.callTimeouts.delete(callId);
        }
    }

    async setActiveCall(callId, callData, ttlSeconds = ACTIVE_CALL_TTL_SECONDS) {
        if (this._isRedisAvailable()) {
            await cache.set(`webrtc:call:${callId}`, callData, ttlSeconds);
            return;
        }

        this.activeCalls.set(callId, callData);
    }

    async getActiveCall(callId) {
        if (this._isRedisAvailable()) {
            return cache.get(`webrtc:call:${callId}`);
        }

        return this.activeCalls.get(callId) || null;
    }

    async deleteActiveCall(callId) {
        if (this._isRedisAvailable()) {
            await cache.del(`webrtc:call:${callId}`);
            return;
        }

        this.activeCalls.delete(callId);
    }

    async setUserSocket(userId, socketId, ttlSeconds = USER_SOCKET_TTL_SECONDS) {
        if (this._isRedisAvailable()) {
            await cache.set(`webrtc:socket:${userId}`, socketId, ttlSeconds);
            return;
        }

        this.userSockets.set(userId, socketId);
    }

    async getUserSocket(userId) {
        if (this._isRedisAvailable()) {
            return cache.get(`webrtc:socket:${userId}`);
        }

        return this.userSockets.get(userId) || null;
    }

    async deleteUserSocket(userId) {
        if (this._isRedisAvailable()) {
            await cache.del(`webrtc:socket:${userId}`);
            return;
        }

        this.userSockets.delete(userId);
    }

    async setUserActiveCall(userId, callId, ttlSeconds = ACTIVE_CALL_TTL_SECONDS) {
        if (this._isRedisAvailable()) {
            await cache.set(`webrtc:user-call:${userId}`, callId, ttlSeconds);
            return;
        }

        this.userActiveCalls.set(userId, callId);
    }

    async getUserActiveCall(userId) {
        if (this._isRedisAvailable()) {
            return cache.get(`webrtc:user-call:${userId}`);
        }

        return this.userActiveCalls.get(userId) || null;
    }

    async deleteUserActiveCall(userId) {
        if (this._isRedisAvailable()) {
            await cache.del(`webrtc:user-call:${userId}`);
            return;
        }

        this.userActiveCalls.delete(userId);
    }

    async cleanupCallState(callId, call = null) {
        const resolvedCall = call || await this.getActiveCall(callId);
        this.clearCallTimeout(callId);
        await this.deleteActiveCall(callId);

        if (resolvedCall) {
            await Promise.all([
                this.deleteUserActiveCall(resolvedCall.callerId),
                this.deleteUserActiveCall(resolvedCall.calleeId),
            ]);
        }
    }

    async getExistingBusyCall(userId) {
        const existingCallId = await this.getUserActiveCall(userId);
        if (!existingCallId) return null;

        const call = await this.getActiveCall(existingCallId);
        if (!call) {
            await this.deleteUserActiveCall(userId);
            return null;
        }

        if (call.status === 'ended' || call.status === 'rejected' || call.status === 'missed') {
            await this.cleanupCallState(existingCallId, call);
            return null;
        }

        return call;
    }

    async validateOrderParticipants({ orderId, callerId, calleeId }) {
        if (!orderId) {
            return { valid: false, message: 'Missing order ID', code: 'INVALID_ORDER' };
        }

        const order = await prisma.order.findUnique({
            where: { id: orderId },
            select: {
                id: true,
                customerId: true,
                riderId: true,
                status: true,
            },
        });

        if (!order) {
            return { valid: false, message: 'Order not found', code: 'ORDER_NOT_FOUND' };
        }

        if (TERMINAL_ORDER_STATUSES.has(order.status)) {
            return {
                valid: false,
                message: `Cannot call on an order that is ${order.status}`,
                code: 'ORDER_TERMINAL',
            };
        }

        if (!order.riderId) {
            return {
                valid: false,
                message: 'Rider is not assigned for this order yet',
                code: 'RIDER_NOT_ASSIGNED',
            };
        }

        const participants = new Set([order.customerId, order.riderId].filter(Boolean));
        if (!participants.has(callerId) || !participants.has(calleeId)) {
            return {
                valid: false,
                message: 'Caller/callee must be order participants',
                code: 'ORDER_PARTICIPANT_REQUIRED',
            };
        }

        if (callerId === calleeId) {
            return {
                valid: false,
                message: 'Caller and callee cannot be the same user',
                code: 'INVALID_PARTICIPANTS',
            };
        }

        return { valid: true };
    }

    async handleRegister(socket, requestedUserId) {
        const authenticatedUserId = socket?.data?.userId || null;
        const requested = typeof requestedUserId === 'string' ? requestedUserId.trim() : '';
        const resolvedUserId = authenticatedUserId || requested;

        if (!resolvedUserId) {
            this.emitError(socket, 'Missing user ID for registration', 'INVALID_REGISTER');
            return;
        }

        if (authenticatedUserId && requested && requested !== authenticatedUserId) {
            console.warn(
                `WebRTC: register mismatch detected. Using authenticated user ${authenticatedUserId} instead of requested ${requested}`
            );
        }

        await this.setUserSocket(resolvedUserId, socket.id);
        socket.userId = resolvedUserId;

        console.log(`WebRTC: User ${resolvedUserId} registered with socket ${socket.id}`);
    }

    async handleCallInitiation(socket, data = {}) {
        const callerId = this.getSocketUserId(socket);
        const claimedCallerId = typeof data.callerId === 'string' ? data.callerId.trim() : '';
        const calleeId = typeof data.calleeId === 'string' ? data.calleeId.trim() : '';
        const orderId = typeof data.orderId === 'string' ? data.orderId.trim() : '';
        const offer = data.offer;
        const callType = typeof data.callType === 'string' ? data.callType.trim().toLowerCase() : VOICE_CALL_TYPE;

        if (!callerId) {
            this.emitError(socket, 'Not authorized for calling', 'NOT_AUTHORIZED');
            return;
        }

        if (claimedCallerId && claimedCallerId !== callerId) {
            this.emitError(socket, 'Caller identity mismatch', 'CALLER_ID_MISMATCH');
            return;
        }

        if (!calleeId || !orderId || !this.isValidSessionDescription(offer)) {
            this.emitError(socket, 'Invalid call payload', 'INVALID_CALL_PAYLOAD');
            return;
        }

        if (callType !== VOICE_CALL_TYPE) {
            this.emitError(socket, 'Only audio calls are supported', 'UNSUPPORTED_CALL_TYPE');
            return;
        }

        const [callerBusyCall, calleeBusyCall] = await Promise.all([
            this.getExistingBusyCall(callerId),
            this.getExistingBusyCall(calleeId),
        ]);

        if (callerBusyCall) {
            this.emitError(socket, 'You already have an active call', 'CALLER_BUSY', {
                activeCallId: callerBusyCall.callId,
            });
            return;
        }

        if (calleeBusyCall) {
            this.emitError(socket, 'Callee is already in another call', 'CALLEE_BUSY', {
                activeCallId: calleeBusyCall.callId,
            });
            return;
        }

        const orderValidation = await this.validateOrderParticipants({ orderId, callerId, calleeId });
        if (!orderValidation.valid) {
            this.emitError(socket, orderValidation.message, orderValidation.code);
            return;
        }

        const callId = this.generateCallId();

        const callData = {
            callId,
            callerId,
            calleeId,
            orderId,
            callType: VOICE_CALL_TYPE,
            status: 'ringing',
            startedAt: new Date().toISOString(),
            offer,
        };

        await Promise.all([
            this.setActiveCall(callId, callData),
            this.setUserActiveCall(callerId, callId),
            this.setUserActiveCall(calleeId, callId),
        ]);

        const calleeSocketId = await this.getUserSocket(calleeId);

        console.log(`WebRTC: Call initiated from ${callerId} to ${calleeId}`);

        if (!calleeSocketId) {
            try {
                const caller = await prisma.user.findUnique({
                    where: { id: callerId },
                    select: { username: true, profilePicture: true },
                });

                await sendCallNotification(
                    calleeId,
                    caller?.username || 'Unknown',
                    callId,
                    VOICE_CALL_TYPE,
                    orderId,
                    caller?.profilePicture || null,
                    callerId
                );

                socket.emit('webrtc:call-ringing', {
                    callId,
                    viaNotification: true,
                });

                this.setCallTimeout(callId);
            } catch (error) {
                console.error('Error sending call notification:', error);
                this.emitError(socket, 'Failed to reach user', 'NOTIFICATION_SEND_FAILED', { callId });
                await this.cleanupCallState(callId, callData);
            }
            return;
        }

        this.io.to(calleeSocketId).emit('webrtc:incoming-call', {
            callId,
            callerId,
            orderId,
            offer,
            callType: VOICE_CALL_TYPE,
        });

        socket.emit('webrtc:call-ringing', { callId });
        this.setCallTimeout(callId);
    }

    async handleCallTimeout(callId) {
        const call = await this.getActiveCall(callId);
        if (!call || call.status !== 'ringing') {
            this.clearCallTimeout(callId);
            return;
        }

        console.log(`WebRTC: Call ${callId} timed out (no answer)`);

        const callerSocketId = await this.getUserSocket(call.callerId);
        if (callerSocketId) {
            this.io.to(callerSocketId).emit('webrtc:call-timeout', { callId });
        }

        await this.saveCallLog(call, {
            duration: 0,
            status: 'missed',
        });

        await this.cleanupCallState(callId, call);
    }

    async getCallDetails(callId) {
        return this.getActiveCall(callId);
    }

    async handleCallAnswer(socket, data = {}) {
        const socketUserId = this.getSocketUserId(socket);
        const callId = typeof data.callId === 'string' ? data.callId.trim() : '';
        const answer = data.answer;

        if (!socketUserId) {
            this.emitError(socket, 'Not authorized for call answering', 'NOT_AUTHORIZED');
            return;
        }

        if (!callId || !this.isValidSessionDescription(answer)) {
            this.emitError(socket, 'Invalid answer payload', 'INVALID_ANSWER_PAYLOAD');
            return;
        }

        const call = await this.getActiveCall(callId);
        if (!call) {
            this.emitError(socket, 'Call not found or expired', 'CALL_NOT_FOUND', { callId });
            return;
        }

        if (socketUserId !== call.calleeId) {
            this.emitError(socket, 'Only the callee can answer this call', 'ANSWER_NOT_ALLOWED', { callId });
            return;
        }

        if (call.status !== 'ringing') {
            this.emitError(socket, 'Call can no longer be answered', 'CALL_NOT_RINGING', {
                callId,
                status: call.status,
            });
            return;
        }

        call.status = 'active';
        call.answeredAt = new Date().toISOString();

        await this.setActiveCall(callId, call);
        this.clearCallTimeout(callId);

        const callerSocketId = await this.getUserSocket(call.callerId);
        if (callerSocketId) {
            this.io.to(callerSocketId).emit('webrtc:call-answered', {
                callId,
                answer,
            });
        }

        console.log(`WebRTC: Call ${callId} answered`);
    }

    async handleIceCandidate(socket, data = {}) {
        const socketUserId = this.getSocketUserId(socket);
        const callId = typeof data.callId === 'string' ? data.callId.trim() : '';
        const candidate = data.candidate;

        if (!socketUserId) {
            this.emitError(socket, 'Not authorized for ICE exchange', 'NOT_AUTHORIZED');
            return;
        }

        if (!callId || !this.isValidIceCandidate(candidate)) {
            this.emitError(socket, 'Invalid ICE candidate payload', 'INVALID_ICE_PAYLOAD');
            return;
        }

        const call = await this.getActiveCall(callId);
        if (!call) {
            this.emitError(socket, 'Call not found or expired', 'CALL_NOT_FOUND', { callId });
            return;
        }

        const isCaller = socketUserId === call.callerId;
        const isCallee = socketUserId === call.calleeId;

        if (!isCaller && !isCallee) {
            this.emitError(socket, 'ICE candidate sender is not part of this call', 'ICE_NOT_ALLOWED', { callId });
            return;
        }

        const targetUserId = isCaller ? call.calleeId : call.callerId;
        const targetSocketId = await this.getUserSocket(targetUserId);

        if (!targetSocketId) {
            return;
        }

        this.io.to(targetSocketId).emit('webrtc:ice-candidate', {
            callId,
            candidate,
        });
    }

    async handleEndCall(socket, data = {}) {
        const socketUserId = this.getSocketUserId(socket);
        const callId = typeof data.callId === 'string' ? data.callId.trim() : '';

        if (!socketUserId || !callId) {
            this.emitError(socket, 'Invalid end-call payload', 'INVALID_END_CALL_PAYLOAD');
            return;
        }

        const call = await this.getActiveCall(callId);
        if (!call) {
            return;
        }

        if (socketUserId !== call.callerId && socketUserId !== call.calleeId) {
            this.emitError(socket, 'Only call participants can end this call', 'END_CALL_NOT_ALLOWED', { callId });
            return;
        }

        const callerSocketId = await this.getUserSocket(call.callerId);
        const calleeSocketId = await this.getUserSocket(call.calleeId);

        if (callerSocketId) {
            this.io.to(callerSocketId).emit('webrtc:call-ended', {
                callId,
                endedBy: socketUserId,
            });
        }

        if (calleeSocketId) {
            this.io.to(calleeSocketId).emit('webrtc:call-ended', {
                callId,
                endedBy: socketUserId,
            });
        }

        const duration = call.answeredAt
            ? Math.max(0, Math.floor((Date.now() - new Date(call.answeredAt).getTime()) / 1000))
            : 0;

        await this.saveCallLog(call, {
            duration,
            status: duration > 0 ? 'completed' : 'missed',
        });

        await this.cleanupCallState(callId, call);

        console.log(`WebRTC: Call ${callId} ended by user ${socketUserId}`);
    }

    async handleRejectCall(socket, data = {}) {
        const socketUserId = this.getSocketUserId(socket);
        const callId = typeof data.callId === 'string' ? data.callId.trim() : '';

        if (!socketUserId || !callId) {
            this.emitError(socket, 'Invalid reject payload', 'INVALID_REJECT_PAYLOAD');
            return;
        }

        const call = await this.getActiveCall(callId);
        if (!call) {
            return;
        }

        if (socketUserId !== call.calleeId) {
            this.emitError(socket, 'Only the callee can reject this call', 'REJECT_NOT_ALLOWED', { callId });
            return;
        }

        const callerSocketId = await this.getUserSocket(call.callerId);
        if (callerSocketId) {
            this.io.to(callerSocketId).emit('webrtc:call-rejected', { callId });
        }

        await this.saveCallLog(call, {
            duration: 0,
            status: 'rejected',
        });

        await this.cleanupCallState(callId, call);

        console.log(`WebRTC: Call ${callId} rejected by callee ${socketUserId}`);
    }

    async handleDisconnect(socket) {
        const userId = this.getSocketUserId(socket);
        if (!userId) {
            return;
        }

        await this.deleteUserSocket(userId);

        const activeCallId = await this.getUserActiveCall(userId);
        if (!activeCallId) {
            console.log(`WebRTC: User ${userId} disconnected`);
            return;
        }

        const call = await this.getActiveCall(activeCallId);
        if (!call) {
            await this.deleteUserActiveCall(userId);
            console.log(`WebRTC: User ${userId} disconnected (stale call mapping cleaned)`);
            return;
        }

        const otherUserId = call.callerId === userId ? call.calleeId : call.callerId;
        const otherSocketId = await this.getUserSocket(otherUserId);

        if (otherSocketId) {
            this.io.to(otherSocketId).emit('webrtc:call-ended', {
                callId: call.callId,
                reason: 'disconnect',
            });
        }

        const duration = call.answeredAt
            ? Math.max(0, Math.floor((Date.now() - new Date(call.answeredAt).getTime()) / 1000))
            : 0;

        await this.saveCallLog(call, {
            duration,
            status: duration > 0 ? 'completed' : 'failed',
        });

        await this.cleanupCallState(call.callId, call);
        console.log(`WebRTC: User ${userId} disconnected and call ${call.callId} was cleaned up`);
    }

    async saveCallLog(call, { duration = 0, status } = {}) {
        try {
            const CallLog = require('../models/CallLog');

            const finalDuration = Number.isFinite(duration) ? Math.max(0, duration) : 0;
            const finalStatus = status || (finalDuration > 0 ? 'completed' : 'missed');

            await CallLog.create({
                order: call.orderId,
                caller: call.callerId,
                recipient: call.calleeId,
                callType: 'webrtc',
                isVideoCall: false,
                status: finalStatus,
                duration: finalDuration,
                startedAt: new Date(call.startedAt),
                endedAt: new Date(),
            });

            console.log(`✅ WebRTC: Call log saved to MongoDB for ${call.callId}`);
        } catch (error) {
            console.error('❌ Error saving call log to MongoDB:', error);
        }
    }
}

module.exports = WebRTCSignalingService;
