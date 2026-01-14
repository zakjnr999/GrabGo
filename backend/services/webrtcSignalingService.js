const { sendCallNotification } = require('./fcm_service');
const cache = require('../utils/cache');

class WebRTCSignalingService {
    constructor(io) {
        this.io = io;
        // Use Redis for production scalability, fallback to Map for development
        this.useRedis = cache.isRedisConnected();
        this.activeCalls = new Map(); // Fallback for development
        this.userSockets = new Map(); // Fallback for development
        this.setupSignaling();

        console.log(`[WebRTC] Using ${this.useRedis ? 'Redis' : 'in-memory Map'} for call state`);
    }

    setupSignaling() {
        this.io.on("connection", (socket) => {
            console.log(`WebRTC: User connected: ${socket.id}`);

            // Register user
            socket.on("webrtc:register", async (userId) => {
                await this.setUserSocket(userId, socket.id);
                socket.userId = userId;
                console.log(
                    `WebRTC: User ${userId} registered with socket ${socket.id}`
                );
            });

            // Initiate call
            socket.on("webrtc:call", async (data) => {
                await this.handleCallInitiation(socket, data);
            });

            // Answer call
            socket.on("webrtc:answer", async (data) => {
                await this.handleCallAnswer(socket, data);
            });

            // ICE candidate exchange
            socket.on("webrtc:ice-candidate", async (data) => {
                await this.handleIceCandidate(socket, data);
            });

            // End call
            socket.on("webrtc:end-call", async (data) => {
                await this.handleEndCall(socket, data);
            });

            // Reject call
            socket.on("webrtc:reject", async (data) => {
                await this.handleRejectCall(socket, data);
            });

            // Disconnect
            socket.on("disconnect", async (data) => {
                await this.handleDisconnect(socket);
            });
        });
    }

    // ==================== Redis Helper Methods ====================

    /**
     * Store active call in Redis or Map
     */
    async setActiveCall(callId, callData) {
        if (this.useRedis) {
            await cache.set(`webrtc:call:${callId}`, callData, 60); // 60 seconds TTL
        } else {
            this.activeCalls.set(callId, callData);
        }
    }

    /**
     * Get active call from Redis or Map
     */
    async getActiveCall(callId) {
        if (this.useRedis) {
            return await cache.get(`webrtc:call:${callId}`);
        } else {
            return this.activeCalls.get(callId);
        }
    }

    /**
     * Delete active call from Redis or Map
     */
    async deleteActiveCall(callId) {
        if (this.useRedis) {
            await cache.del(`webrtc:call:${callId}`);
        } else {
            this.activeCalls.delete(callId);
        }
    }

    /**
     * Store user socket mapping in Redis or Map
     */
    async setUserSocket(userId, socketId) {
        if (this.useRedis) {
            await cache.set(`webrtc:socket:${userId}`, socketId, 3600); // 1 hour TTL
        } else {
            this.userSockets.set(userId, socketId);
        }
    }

    /**
     * Get user socket from Redis or Map
     */
    async getUserSocket(userId) {
        if (this.useRedis) {
            return await cache.get(`webrtc:socket:${userId}`);
        } else {
            return this.userSockets.get(userId);
        }
    }

    /**
     * Delete user socket from Redis or Map
     */
    async deleteUserSocket(userId) {
        if (this.useRedis) {
            await cache.del(`webrtc:socket:${userId}`);
        } else {
            this.userSockets.delete(userId);
        }
    }

    // ==================== End Redis Helper Methods ====================


    async handleCallInitiation(socket, data) {
        const { calleeId, callerId, orderId, offer, callType } = data;

        console.log(`WebRTC: Call initiated from ${callerId} to ${calleeId}`);

        const callId = `call_${Date.now()}_${Math.random()
            .toString(36)
            .substring(2, 9)}`;

        // Store call info
        await this.setActiveCall(callId, {
            callId,
            callerId,
            calleeId,
            orderId,
            callType, // audio for now but may add video later
            status: "ringing",
            startedAt: new Date().toISOString(), // Store as ISO string for Redis compatibility
            offer,
        });

        // Get callee socket
        const calleeSocketId = await this.getUserSocket(calleeId);

        if (!calleeSocketId) {
            // User is OFFLINE - send push notification
            console.log(`WebRTC: User ${calleeId} is offline, sending push notification`);

            try {
                // Get caller info for notification
                const User = require('../models/User');
                const caller = await User.findById(callerId).select('username profilePicture');

                // Send push notification
                await sendCallNotification(
                    calleeId,
                    caller.username || 'Unknown',
                    callId,
                    callType,
                    orderId,
                    caller.profilePicture,
                    callerId
                );

                // Notify caller that we are trying to reach the callee
                socket.emit('webrtc:call-ringing', {
                    callId,
                    viaNotification: true
                });

                // Set timeout for call (30 seconds)
                setTimeout(async () => {
                    const call = await this.getActiveCall(callId);
                    if (call && call.status === 'ringing') {
                        // call was not answered
                        this.handleCallTimeout(callId);
                    }
                }, 30000);
            } catch (error) {
                console.error('Error sending call notification:', error);
                socket.emit('webrtc:error', {
                    error: 'Failed to reach user',
                    callId,
                });
                await this.deleteActiveCall(callId);
            }
            return;
        }

        // User is online so we Send call offer to callee
        this.io.to(calleeSocketId).emit("webrtc:incoming-call", {
            callId,
            callerId,
            orderId,
            offer,
            callType
        });

        // Notify caller that call is ringing
        socket.emit("webrtc:call-ringing", { callId });
    }
    async handleCallTimeout(callId) {
        const call = await this.getActiveCall(callId);
        if (!call) return;

        console.log(`WebRTC: Call ${callId} timed out (no answer)`);

        // Notify caller
        const callerSocketId = await this.getUserSocket(call.callerId);
        if (callerSocketId) {
            this.io.to(callerSocketId).emit('webrtc:call-timeout', { callId });
        }

        await this.deleteActiveCall(callId);
    }

    async getCallDetails(callId) {
        return await this.getActiveCall(callId);
    }

    async handleCallAnswer(socket, data) {
        const { callId, answer } = data;

        const call = await this.getActiveCall(callId);
        if (!call) {
            socket.emit("webrtc:error", { error: "Call not found" });
            return;
        }

        console.log(`WebRTC: Call ${callId} answered`);

        // Update call status
        call.status = "active";
        call.answeredAt = new Date().toISOString(); // Store as ISO string for Redis compatibility

        // IMPORTANT: Save updated call back to Redis
        await this.setActiveCall(callId, call);

        // Send answer to caller
        const callerSocketId = await this.getUserSocket(call.callerId);
        if (callerSocketId) {
            this.io.to(callerSocketId).emit("webrtc:call-answered", {
                callId,
                answer,
            });
        }
    }

    async handleIceCandidate(socket, data) {
        const { callId, candidate, targetUserId } = data;

        const targetSocketId = await this.getUserSocket(targetUserId);
        if (targetSocketId) {
            this.io.to(targetSocketId).emit("webrtc:ice-candidate", {
                callId,
                candidate,
            });
        }
    }

    async handleEndCall(socket, data) {
        const { callId } = data;

        const call = await this.getActiveCall(callId);
        if (!call) return;

        console.log(`WebRTC: Call ${callId} ended`);

        // Notify both parties
        const callerSocketId = await this.getUserSocket(call.callerId);
        const calleeSocketId = await this.getUserSocket(call.calleeId);

        if (callerSocketId) {
            this.io.to(callerSocketId).emit("webrtc:call-ended", { callId });
        }
        if (calleeSocketId) {
            this.io.to(calleeSocketId).emit("webrtc:call-ended", { callId });
        }

        // Calculate duration and save call log
        const duration = call.answeredAt
            ? Math.floor((Date.now() - new Date(call.answeredAt).getTime()) / 1000)
            : 0;

        this.saveCallLog(call, duration);
        await this.deleteActiveCall(callId);
    }

    async handleRejectCall(socket, data) {
        const { callId } = data;

        const call = await this.getActiveCall(callId);
        if (!call) return;

        console.log(`WebRTC: Call ${callId} rejected`);

        // Notify caller
        const callerSocketId = await this.getUserSocket(call.callerId);
        if (callerSocketId) {
            this.io.to(callerSocketId).emit("webrtc:call-rejected", { callId });
        }

        await this.deleteActiveCall(callId);
    }

    async handleDisconnect(socket) {
        const userId = socket.userId;
        if (userId) {
            await this.deleteUserSocket(userId);
            console.log(`WebRTC: User ${userId} disconnected`);

            // End any active calls for this user
            // Note: In Redis mode, we can't iterate all calls efficiently
            // Calls will timeout naturally after 60 seconds
            // For immediate cleanup, the client should send end-call event
        }
    }

    async saveCallLog(call, duration) {
        try {
            const CallLog = require("../models/CallLog");

            await CallLog.create({
                order: call.orderId,
                caller: call.callerId,
                recipient: call.calleeId,
                callType: "webrtc",
                status: duration > 0 ? "completed" : "missed",
                duration,
                startedAt: new Date(call.startedAt), // Convert ISO string to Date
                endedAt: new Date(),
            });

            console.log(`WebRTC: Call log saved for ${call.callId}`);
        } catch (error) {
            console.error("Error saving call log:", error);
        }
    }

    async getUserActiveCall(userId) {
        // Note: This method is not efficient with Redis
        // Consider storing user->callId mapping separately if needed
        if (!this.useRedis) {
            for (const call of this.activeCalls.values()) {
                if (call.callerId === userId || call.calleeId === userId) {
                    return call;
                }
            }
        }
        return null;
    }
}

module.exports = WebRTCSignalingService;