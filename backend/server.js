const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, ".env") });

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const compression = require("compression");
const http = require("http");
const { Server } = require("socket.io");
const WebRTCSignalingService = require("./services/webrtcSignalingService");
const jwt = require("jsonwebtoken");
const prisma = require("./config/prisma");
const connectMongoDB = require("./config/mongodb");
const { initIO } = require("./utils/socket");
const callRoutes = require("./routes/calls");
const { apiGlobalRateLimit } = require("./middleware/fraud_rate_limit");
const { verifyEmailService } = require("./utils/emailService");
const cache = require("./utils/cache");
const { hashIdentifier } = require("./services/fraud/fraud_context");
const logger = require("./utils/logger");
const metrics = require("./utils/metrics");
const { bootstrapDependencies, getReadinessReport } = require("./bootstrap/dependencies");
const {
  startBackgroundJobs,
  stopBackgroundJobs,
  areBackgroundJobsRunning,
} = require("./bootstrap/background_jobs");

const app = express();
const server = http.createServer(app);

const parseAllowedOrigins = () => {
  const configuredOrigins = (process.env.ALLOWED_ORIGINS || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (configuredOrigins.length > 0) {
    return configuredOrigins;
  }

  if (process.env.NODE_ENV === "production") {
    throw new Error("ALLOWED_ORIGINS is required in production");
  }

  return [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
  ];
};

const allowedOrigins = parseAllowedOrigins();
const isAllowedOrigin = (origin) => !origin || allowedOrigins.includes(origin);
const corsOriginHandler = (origin, callback) => {
  if (isAllowedOrigin(origin)) {
    return callback(null, true);
  }

  return callback(new Error("Not allowed by CORS"));
};

const safeServerMessagePatterns = [
  /^server error$/i,
  /^internal server error$/i,
  /^failed to\b/i,
  /^unable to\b/i,
  /^.*unavailable.*$/i,
  /^.*not available.*$/i,
];

const shouldRunBackgroundJobs = process.env.RUN_BACKGROUND_JOBS !== "false";
let roomCleanupIntervalId = null;

const io = new Server(server, {
  cors: {
    origin: corsOriginHandler,
    methods: ["GET", "POST"],
    credentials: true,
  },
});

// Initialize Socket.IO singleton for global access
initIO(io);
app.set('io', io);

// Initialize WebRTC signaling
const webrtcSignaling = new WebRTCSignalingService(io);
logger.info("webrtc_signaling_initialized");

// Initialize socket service for tracking
const socketService = require('./services/socket_service');
socketService.initialize(io);


// Track per-chat presence across all sockets so that a user only appears
// offline for a chat when all of their sockets for that chat have
// disconnected.
const chatPresence = new Map(); // key: `${chatId}:${userId}`, value: connection count
const parseCoordinate = (value) => {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};
const isValidLatitude = (value) => Number.isFinite(value) && value >= -90 && value <= 90;
const isValidLongitude = (value) => Number.isFinite(value) && value >= -180 && value <= 180;
const parsePositiveInt = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return parsed;
};
const normalizeLimiterValue = (value, fallback = 'unknown') => {
  if (value === null || value === undefined) return fallback;
  const normalized = String(value).trim();
  return normalized || fallback;
};

const SOCKET_RATE_LIMITS = {
  chatJoin: {
    limit: parsePositiveInt(process.env.WS_RATE_CHAT_JOIN_LIMIT, 60),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_CHAT_JOIN_WINDOW_SECONDS, 60),
  },
  chatTyping: {
    limit: parsePositiveInt(process.env.WS_RATE_CHAT_TYPING_LIMIT, 180),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_CHAT_TYPING_WINDOW_SECONDS, 60),
  },
  chatMarkRead: {
    limit: parsePositiveInt(process.env.WS_RATE_CHAT_MARK_READ_LIMIT, 120),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_CHAT_MARK_READ_WINDOW_SECONDS, 60),
  },
  joinOrder: {
    limit: parsePositiveInt(process.env.WS_RATE_JOIN_ORDER_LIMIT, 120),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_JOIN_ORDER_WINDOW_SECONDS, 60),
  },
  riderGoOnline: {
    limit: parsePositiveInt(process.env.WS_RATE_RIDER_GO_ONLINE_LIMIT, 30),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_RIDER_GO_ONLINE_WINDOW_SECONDS, 60),
  },
  riderGoOffline: {
    limit: parsePositiveInt(process.env.WS_RATE_RIDER_GO_OFFLINE_LIMIT, 30),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_RIDER_GO_OFFLINE_WINDOW_SECONDS, 60),
  },
  riderLocationUpdate: {
    limit: parsePositiveInt(process.env.WS_RATE_RIDER_LOCATION_UPDATE_LIMIT, 1800),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_RIDER_LOCATION_UPDATE_WINDOW_SECONDS, 60),
  },
  reservationRespond: {
    limit: parsePositiveInt(process.env.WS_RATE_RESERVATION_RESPOND_LIMIT, 40),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_RESERVATION_RESPOND_WINDOW_SECONDS, 60),
  },
  reservationGetActive: {
    limit: parsePositiveInt(process.env.WS_RATE_RESERVATION_GET_ACTIVE_LIMIT, 120),
    windowSeconds: parsePositiveInt(process.env.WS_RATE_RESERVATION_GET_ACTIVE_WINDOW_SECONDS, 60),
  },
};

const buildSocketRateLimitKey = ({ eventName, userId, resourceId }) => {
  const hashedUser = hashIdentifier(normalizeLimiterValue(userId, 'unknown_user'), 'ws_user');
  const hashedResource = hashIdentifier(
    normalizeLimiterValue(resourceId, 'global'),
    'ws_resource'
  );
  return `grabgo:fraud:throttle:ws:${eventName}:${hashedUser}:${hashedResource}`;
};

const emitSocketRateLimit = (socket, eventName, retryAfter) => {
  socket.emit('socket:rate_limit', {
    success: false,
    message: 'Too many realtime requests',
    event: eventName,
    riskCode: 'SOCKET_EVENT_VELOCITY_LIMIT',
    retryAfter: retryAfter >= 0 ? retryAfter : 1,
  });
};

const enforceSocketRateLimit = async (
  socket,
  { eventName, limit, windowSeconds, resourceId = null }
) => {
  try {
    if (!limit || !windowSeconds) return true;

    const key = buildSocketRateLimitKey({
      eventName,
      userId: socket?.data?.userId || 'unknown_user',
      resourceId,
    });
    const count = await cache.incr(key, windowSeconds);
    if (count <= limit) {
      return true;
    }

    const retryAfter = await cache.ttl(key);
    emitSocketRateLimit(socket, eventName, retryAfter);
    return false;
  } catch (error) {
    // Fail-open for availability: socket traffic should continue on limiter errors.
    console.error(`[SocketRateLimit] ${eventName} error:`, error.message);
    return true;
  }
};

io.use(async (socket, next) => {
  try {
    const headers = socket.handshake.headers || {};
    let token;

    const authHeader =
      headers.authorization ||
      headers.Authorization;

    if (authHeader && typeof authHeader === "string" && authHeader.startsWith("Bearer ")) {
      token = authHeader.split(" ")[1];
    } else if (socket.handshake.auth && typeof socket.handshake.auth.token === "string") {
      token = socket.handshake.auth.token;
    }

    if (!token) {
      return next(new Error("Not authorized, no token provided"));
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      select: { id: true, role: true, isActive: true }
    });

    if (!user || !user.isActive) {
      return next(new Error("Not authorized"));
    }

    socket.data.userId = user.id;
    socket.data.userRole = user.role;
    return next();
  } catch (error) {
    console.error("Socket auth error:", error.message);
    return next(new Error("Not authorized"));
  }
});


io.on("connection", (socket) => {
  console.log("🔌 New WebSocket connection", socket.id);

  // Join user-specific room for targeted notifications
  const userId = socket.data.userId;
  if (userId) {
    socket.join(`user:${userId}`);
    socketService.addUserSocket(userId, socket.id);
    console.log(`✅ User ${userId} joined notification room`);
  }

  socket.on("chat:join", async (payload = {}) => {
    try {
      const { chatId } = payload;
      const userId = socket.data.userId;
      if (!chatId || !userId) return;
      const allowed = await enforceSocketRateLimit(socket, {
        eventName: 'chat:join',
        resourceId: chatId,
        ...SOCKET_RATE_LIMITS.chatJoin,
      });
      if (!allowed) return;

      const chat = await prisma.chat.findUnique({
        where: { id: chatId },
        select: { customerId: true, riderId: true }
      });
      if (!chat) return;

      const userIdStr = userId.toString();
      const isParticipant =
        chat.customerId === userIdStr || chat.riderId === userIdStr;

      if (!isParticipant) {
        console.warn(
          `Unauthorized chat:join attempt. userId=${userIdStr}, chatId=${chatId}`
        );
        return;
      }

      const room = `chat:${chatId}`;
      socket.join(room);

      if (!socket.data.chats) {
        socket.data.chats = new Set();
      }
      socket.data.chats.add(room);

      const presenceKey = `${chatId}:${userIdStr}`;
      const previousCount = chatPresence.get(presenceKey) || 0;
      const nextCount = previousCount + 1;
      chatPresence.set(presenceKey, nextCount);

      if (previousCount === 0) {
        // Notify others in the room that this user is now online
        socket.to(room).emit("chat:presence", { chatId, userId: userIdStr, online: true });
      }

      // Check if the other participant is online and notify the joining user
      const otherUserId = chat.customerId === userIdStr
        ? chat.riderId
        : chat.customerId;

      if (otherUserId) {
        const otherPresenceKey = `${chatId}:${otherUserId}`;
        const otherCount = chatPresence.get(otherPresenceKey) || 0;

        // Also verify the user actually has connected sockets in this room
        const socketsInRoom = await io.in(room).fetchSockets();
        const otherUserHasSocket = socketsInRoom.some(
          (s) => s.data.userId === otherUserId && s.id !== socket.id
        );

        const isOnline = otherCount > 0 && otherUserHasSocket;

        // Clean up stale presence data if count is positive but no socket exists
        if (otherCount > 0 && !otherUserHasSocket) {
          chatPresence.delete(otherPresenceKey);
          console.log(`Cleaned up stale presence for ${otherPresenceKey}`);
        }

        if (isOnline) {
          // The other user is online, notify the joining user
          socket.emit("chat:presence", { chatId, userId: otherUserId, online: true });
        } else {
          // The other user is offline, send their last seen time
          const otherUser = await prisma.user.findUnique({
            where: { id: otherUserId },
            select: { lastSeenAt: true }
          });
          socket.emit("chat:presence", {
            chatId,
            userId: otherUserId,
            online: false,
            lastSeenAt: otherUser?.lastSeenAt || null
          });
        }
      }
    } catch (error) {
      console.error("chat:join error:", error.message);
    }
  });

  socket.on("chat:typing", async (payload = {}) => {
    const { chatId, isTyping } = payload;
    const userId = socket.data.userId;
    if (!chatId || !userId) return;
    const allowed = await enforceSocketRateLimit(socket, {
      eventName: 'chat:typing',
      resourceId: chatId,
      ...SOCKET_RATE_LIMITS.chatTyping,
    });
    if (!allowed) return;
    const userIdStr = userId.toString();
    const room = `chat:${chatId}`;
    socket.to(room).emit("chat:typing", {
      chatId,
      userId: userIdStr,
      isTyping: !!isTyping,
    });
  });

  socket.on("chat:mark_read", async (payload = {}) => {
    try {
      const { chatId } = payload;
      const userId = socket.data.userId;
      if (!chatId || !userId) return;
      const allowed = await enforceSocketRateLimit(socket, {
        eventName: 'chat:mark_read',
        resourceId: chatId,
        ...SOCKET_RATE_LIMITS.chatMarkRead,
      });
      if (!allowed) return;

      const chat = await prisma.chat.findUnique({
        where: { id: chatId },
        include: { messages: true }
      });
      if (!chat) return;

      const userIdStr = userId.toString();
      const isParticipant =
        chat.customerId === userIdStr || chat.riderId === userIdStr;

      if (!isParticipant) return;

      // In Prisma, we'll iterate through messages and update readBy if needed
      // This is a bit more complex for a relational DB if readBy is a string[]
      // We'll update each message that needs it

      const unreadMessages = chat.messages.filter(msg => !msg.readBy.includes(userIdStr));

      if (unreadMessages.length > 0) {
        await Promise.all(unreadMessages.map(msg =>
          prisma.chatMessage.update({
            where: { id: msg.id },
            data: {
              readBy: {
                set: [...msg.readBy, userIdStr]
              }
            }
          })
        ));

        const room = `chat:${chatId}`;
        io.to(room).emit("chat:read", {
          chatId,
          userId: userIdStr,
          readAt: new Date().toISOString(),
        });
      }
    } catch (error) {
      console.error("chat:mark_read error:", error.message);
    }
  });

  socket.on("disconnect", async () => {
    const userId = socket.data.userId;
    const chats = socket.data.chats;
    const lastSeenAt = new Date();

    if (userId && chats && typeof chats.forEach === "function") {
      const userIdStr = userId.toString();

      // Update user's lastSeenAt timestamp
      try {
        await prisma.user.update({
          where: { id: userId },
          data: { lastSeenAt }
        });
      } catch (err) {
        console.error("Failed to update lastSeenAt:", err.message);
      }

      chats.forEach((room) => {
        const chatId = room.replace("chat:", "");
        const presenceKey = `${chatId}:${userIdStr}`;
        const previousCount = chatPresence.get(presenceKey) || 0;
        const nextCount = previousCount - 1;

        if (nextCount <= 0) {
          chatPresence.delete(presenceKey);
          socket
            .to(room)
            .emit("chat:presence", { chatId, userId: userIdStr, online: false, lastSeenAt });
        } else {
          chatPresence.set(presenceKey, nextCount);
        }
      });
    }

    // SECURITY: Clean up notification room
    if (userId) {
      socketService.removeUserSocket(userId);
      if (socket.data.userRole === 'rider') {
        socketService.removeRiderSocket(userId, socket.id);
      }

      const userRoom = `user:${userId}`;
      socket.leave(userRoom);

      // Check if room is now empty
      const room = io.sockets.adapter.rooms.get(userRoom);
      if (!room || room.size === 0) {
        console.log(`🧹 Cleaned up empty notification room for user ${userId}`);
      }
    }

    console.log("🔌 WebSocket disconnected", socket.id);
  });

  // ==================== ORDER TRACKING SOCKET HANDLERS ====================

  // Join order tracking room (only customer/rider/admin for that order)
  socket.on("join_order", async (payload = {}) => {
    const { orderId } = payload;
    if (!orderId) {
      console.warn("⚠️ join_order: No orderId provided");
      return;
    }
    const allowed = await enforceSocketRateLimit(socket, {
      eventName: 'join_order',
      resourceId: orderId,
      ...SOCKET_RATE_LIMITS.joinOrder,
    });
    if (!allowed) return;

    try {
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: { id: true, customerId: true, riderId: true },
      });

      if (!order) {
        socket.emit("tracking:error", { orderId, message: "Order not found" });
        console.warn(`⚠️ join_order: Order ${orderId} not found`);
        return;
      }

      const userId = socket.data.userId;
      const userRole = socket.data.userRole;
      const isAuthorized =
        userRole === "admin" ||
        order.customerId === userId ||
        (order.riderId && order.riderId === userId);

      if (!isAuthorized) {
        socket.emit("tracking:error", { orderId, message: "Not authorized to track this order" });
        console.warn(`⚠️ Unauthorized join_order attempt. userId=${userId}, orderId=${orderId}`);
        return;
      }

      const roomName = `order:${orderId}`;
      socket.join(roomName);
      console.log(`📦 User ${socket.data.userId} joined order tracking room: ${roomName}`);

      // Store the order room in socket data for cleanup
      if (!socket.data.orderRooms) {
        socket.data.orderRooms = new Set();
      }
      socket.data.orderRooms.add(roomName);
    } catch (error) {
      console.error(`join_order error for order ${orderId}:`, error.message);
      socket.emit("tracking:error", { orderId, message: "Failed to join tracking room" });
    }
  });

  // Leave order tracking room
  socket.on("leave_order", (payload = {}) => {
    const { orderId } = payload;
    if (!orderId) return;

    const roomName = `order:${orderId}`;
    socket.leave(roomName);
    console.log(`📦 User ${socket.data.userId} left order tracking room: ${roomName}`);

    if (socket.data.orderRooms) {
      socket.data.orderRooms.delete(roomName);
    }
  });

  // ==================== ORDER RESERVATION SOCKET HANDLERS ====================

  // Rider goes online (registers for order reservations)
  socket.on("rider:go_online", async (data) => {
    const userId = socket.data.userId;
    const userRole = socket.data.userRole;

    if (userRole !== 'rider') {
      console.warn(`⚠️ Non-rider user ${userId} tried to go online`);
      return;
    }
    const allowed = await enforceSocketRateLimit(socket, {
      eventName: 'rider:go_online',
      ...SOCKET_RATE_LIMITS.riderGoOnline,
    });
    if (!allowed) return;

    try {
      // Update rider's online status in MongoDB RiderStatus
      const RiderStatus = require('./models/RiderStatus');
      const { latitude, longitude, batteryLevel, isCharging } = data || {};
      const parsedLat = parseCoordinate(latitude);
      const parsedLon = parseCoordinate(longitude);
      const hasProvidedLatitude = latitude !== null && latitude !== undefined && latitude !== '';
      const hasProvidedLongitude = longitude !== null && longitude !== undefined && longitude !== '';

      if (
        (hasProvidedLatitude && (parsedLat === null || !isValidLatitude(parsedLat))) ||
        (hasProvidedLongitude && (parsedLon === null || !isValidLongitude(parsedLon)))
      ) {
        socket.emit('rider:status', {
          online: false,
          message: 'Invalid coordinates provided',
        });
        return;
      }

      // Use provided location or default
      const lat = parsedLat ?? 5.6037;
      const lon = parsedLon ?? -0.187;
      const battery = typeof batteryLevel === 'number' ? batteryLevel : 100;
      const charging = isCharging === true;

      await RiderStatus.goOnline(userId, lon, lat, true, battery, charging);

      // Track rider socket
      socketService.addRiderSocket(userId, socket.id);

      console.log(`🚴 Rider ${userId} is now online via socket`);
      socket.emit('rider:status', { online: true });
    } catch (error) {
      console.error(`Error setting rider online: ${error.message}`);
    }
  });

  // Rider goes offline
  socket.on("rider:go_offline", async () => {
    const userId = socket.data.userId;
    const userRole = socket.data.userRole;

    if (userRole !== 'rider') return;
    const allowed = await enforceSocketRateLimit(socket, {
      eventName: 'rider:go_offline',
      ...SOCKET_RATE_LIMITS.riderGoOffline,
    });
    if (!allowed) return;

    try {
      // Update rider's online status in MongoDB RiderStatus
      const RiderStatus = require('./models/RiderStatus');
      await RiderStatus.goOffline(userId);

      // Remove rider socket tracking
      socketService.removeRiderSocket(userId, socket.id);

      console.log(`🚴 Rider ${userId} is now offline via socket`);
      socket.emit('rider:status', { online: false });
    } catch (error) {
      console.error(`Error setting rider offline: ${error.message}`);
    }
  });

  // Rider updates their location
  socket.on("rider:location_update", async (data) => {
    const userId = socket.data.userId;
    const userRole = socket.data.userRole;

    if (userRole !== 'rider') return;
    const allowed = await enforceSocketRateLimit(socket, {
      eventName: 'rider:location_update',
      ...SOCKET_RATE_LIMITS.riderLocationUpdate,
    });
    if (!allowed) return;

    const { latitude, longitude, batteryLevel, isCharging } = data || {};
    const parsedLat = parseCoordinate(latitude);
    const parsedLon = parseCoordinate(longitude);
    if (!isValidLatitude(parsedLat) || !isValidLongitude(parsedLon)) return;

    try {
      // Update location in MongoDB RiderStatus
      const RiderStatus = require('./models/RiderStatus');

      const updateData = {
        'location.coordinates': [parsedLon, parsedLat],
        lastLocationUpdate: new Date(),
        lastActiveAt: new Date()
      };

      // Include battery if provided
      if (typeof batteryLevel === 'number') {
        updateData.batteryLevel = Math.min(100, Math.max(0, batteryLevel));
      }
      if (typeof isCharging === 'boolean') {
        updateData.isCharging = isCharging;
      }

      await RiderStatus.findOneAndUpdate(
        { riderId: userId },
        { $set: updateData },
        { upsert: true }
      );
    } catch (error) {
      console.error(`Error updating rider location: ${error.message}`);
    }
  });

  // Rider responds to order reservation (accept/decline)
  socket.on("reservation:respond", async (payload = {}) => {
    const { reservationId, action, declineReason } = payload;
    const userId = socket.data.userId;
    const userRole = socket.data.userRole;

    if (userRole !== 'rider') {
      socket.emit('reservation:response', {
        success: false,
        error: 'Only riders can respond to reservations'
      });
      return;
    }
    const allowed = await enforceSocketRateLimit(socket, {
      eventName: 'reservation:respond',
      resourceId: reservationId,
      ...SOCKET_RATE_LIMITS.reservationRespond,
    });
    if (!allowed) {
      socket.emit('reservation:response', {
        success: false,
        error: 'Too many reservation responses. Please retry shortly.',
      });
      return;
    }

    try {
      const dispatchService = require('./services/dispatch_service');
      let result;

      if (action === 'accept') {
        result = await dispatchService.acceptReservation(reservationId, userId);
      } else if (action === 'decline') {
        result = await dispatchService.declineReservation(reservationId, userId, declineReason);
      } else {
        result = { success: false, error: 'Invalid action. Use "accept" or "decline".' };
      }

      socket.emit('reservation:response', result);

      if (result.success && action === 'accept') {
        // Broadcast that order was taken so other riders can remove it from their UI
        socketService.broadcastOrderTaken(result.orderId, userId);
      }
    } catch (error) {
      console.error(`Error responding to reservation: ${error.message}`);
      socket.emit('reservation:response', {
        success: false,
        error: 'Failed to respond to reservation'
      });
    }
  });

  // Get rider's active reservation (if any)
  socket.on("reservation:get_active", async () => {
    const userId = socket.data.userId;
    const userRole = socket.data.userRole;

    if (userRole !== 'rider') {
      socket.emit('reservation:active', { reservation: null });
      return;
    }
    const allowed = await enforceSocketRateLimit(socket, {
      eventName: 'reservation:get_active',
      ...SOCKET_RATE_LIMITS.reservationGetActive,
    });
    if (!allowed) {
      socket.emit('reservation:active', {
        reservation: null,
        error: 'Too many requests. Please retry shortly.',
      });
      return;
    }

    try {
      const dispatchService = require('./services/dispatch_service');
      const reservation = await dispatchService.getActiveReservationForRider(userId);
      socket.emit('reservation:active', { reservation });
    } catch (error) {
      console.error(`Error getting active reservation: ${error.message}`);
      socket.emit('reservation:active', {
        reservation: null,
        error: 'Failed to fetch active reservation',
      });
    }
  });
});

const startRoomCleanupLoop = () => {
  if (roomCleanupIntervalId) return;

  roomCleanupIntervalId = setInterval(() => {
    const rooms = io.sockets.adapter.rooms;
    let cleanedCount = 0;

    rooms.forEach((sockets, roomName) => {
      // Clean up user notification rooms with no connections
      if (roomName.startsWith('user:') && sockets.size === 0) {
        rooms.delete(roomName);
        cleanedCount++;
      }
    });

    if (cleanedCount > 0) {
      logger.info("socket_room_cleanup_completed", { cleanedCount });
    }
  }, 3600000);
};

const stopRoomCleanupLoop = () => {
  if (!roomCleanupIntervalId) return;
  clearInterval(roomCleanupIntervalId);
  roomCleanupIntervalId = null;
};

// Middleware
app.use(helmet());
app.use(compression());
app.use((req, res, next) => {
  const requestStartedAt = process.hrtime.bigint();
  req.id = req.headers["x-request-id"] || `req_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  res.setHeader("X-Request-Id", req.id);

  const originalJson = res.json.bind(res);
  res.json = (payload) => {
    if (payload && typeof payload === "object" && !Array.isArray(payload) && res.statusCode >= 500) {
      const sanitizedPayload = { ...payload };
      delete sanitizedPayload.error;

      if (typeof sanitizedPayload.message === "string") {
        if (!safeServerMessagePatterns.some((pattern) => pattern.test(sanitizedPayload.message))) {
          sanitizedPayload.message = "Internal server error";
        }
      } else if (sanitizedPayload.success === false) {
        sanitizedPayload.message = "Internal server error";
      }

      return originalJson(sanitizedPayload);
    }

    return originalJson(payload);
  };

  res.on("finish", () => {
    const durationMs = Number(process.hrtime.bigint() - requestStartedAt) / 1e6;
    const route =
      req.route?.path && req.baseUrl
        ? `${req.baseUrl}${req.route.path}`
        : req.route?.path || req.baseUrl || "unmatched";

    metrics.observeHttpRequest({
      method: req.method,
      route,
      status: res.statusCode,
      durationMs,
    });
  });

  next();
});
app.use(
  morgan((tokens, req, res) => JSON.stringify({
    time: new Date().toISOString(),
    level: "info",
    message: "http_request",
    requestId: req.id,
    method: tokens.method(req, res),
    url: tokens.url(req, res),
    status: Number(tokens.status(req, res) || 0),
    responseTimeMs: Number(tokens["response-time"](req, res) || 0),
    contentLength: Number(tokens.res(req, res, "content-length") || 0),
  }))
);
app.use(
  cors({
    origin: corsOriginHandler,
    credentials: true,
  })
);
// Raw parser for payment webhook signature verification.
app.use("/api/payments/webhooks/paystack", express.raw({ type: "application/json" }));
app.use("/api/subscriptions/webhook", express.raw({ type: "application/json" }));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));
app.use("/api", apiGlobalRateLimit);

app.get("/api/metrics", async (req, res) => {
  try {
    const report = await getReadinessReport();
    metrics.setDependencyHealth(report.dependencies);
    metrics.setBackgroundJobsEnabled(areBackgroundJobsRunning());
    res.setHeader("Content-Type", "text/plain; version=0.0.4; charset=utf-8");
    return res.status(200).send(metrics.renderMetrics());
  } catch (error) {
    logger.error("metrics_render_failed", { error });
    return res.status(500).type("text/plain").send("Internal server error\n");
  }
});

// Serve uploaded files
app.use("/uploads", express.static("uploads"));

// Routes
app.use("/api/users", require("./routes/auth"));
app.use("/api/users", require("./routes/notification_settings"));
app.use("/api/restaurants", require("./routes/restaurants"));
app.use("/api/orders", require("./routes/orders"));
app.use("/api/item-reviews", require("./routes/item_reviews"));
app.use("/api/vendor-reviews", require("./routes/vendor_reviews"));
app.use("/api/checkout-sessions", require("./routes/checkout_sessions"));
app.use("/api/payments", require("./routes/payments"));
app.use("/api/fraud", require("./routes/fraud"));
app.use("/api/admin/fraud", require("./routes/admin_fraud"));
app.use("/api/home", require("./routes/home"));
app.use("/api/search", require("./routes/search"));
app.use("/api/categories", require("./routes/categories"));
app.use("/api/foods", require("./routes/foods"));
app.use("/api/groceries", require("./routes/groceries"));
app.use("/api/pharmacies", require("./routes/pharmacies"));
app.use("/api/grabmart", require("./routes/grabmart"));
app.use("/api/riders", require("./routes/riders"));
app.use("/api/rider-analytics", require("./routes/rider_analytics"));
app.use("/api/chats", require("./routes/chats"));
app.use("/api/notifications", require("./routes/notifications"));
app.use("/api/scheduled-notifications", require("./routes/scheduled_notifications"));
app.use("/api/referral", require("./routes/referrals"));
app.use("/api/promotions", require("./routes/promotions"));
app.use("/api/events", require("./routes/events"));
app.use("/api/vendor/events", require("./routes/vendor_events"));
app.use("/api/admin/events", require("./routes/admin_events"));
app.use("/api/cart", require("./routes/cart"));
app.use("/api/favorites", require("./routes/favorites"));
app.use("/api/promo", require("./routes/promo"));
app.use("/api/pickup", require("./routes/pickup"));
app.use("/api/parcel", require("./routes/parcel"));
if (process.env.ENABLE_TEST_ROUTES === "true" || process.env.NODE_ENV !== "production") {
  app.use("/api/test", require("./routes/test"));
}
app.use("/api/tracking", require("./routes/tracking_routes"));
app.use("/api/credits", require("./routes/credits"));
app.use("/api/subscriptions", require("./routes/subscriptions"));
app.use("/api/addresses", require("./routes/address"));
app.use('/api/calls', callRoutes);

app.set('webrtcSignaling', webrtcSignaling);

app.get("/api/health/live", (req, res) => {
  res.status(200).json({ status: "ok" });
});

app.get("/api/health/ready", async (req, res) => {
  const report = await getReadinessReport();
  return res.status(report.status === "ok" ? 200 : 503).json(report);
});

app.get("/api/health", async (req, res) => {
  const report = await getReadinessReport();
  return res.status(report.status === "ok" ? 200 : 503).json(report);
});

// Email health check
app.get("/api/health/email", async (req, res) => {
  const result = await verifyEmailService();

  if (result.success) {
    return res.status(200).json({
      status: "ok",
      service: "smtp",
      ...result,
    });
  }

  return res.status(503).json({
    status: "error",
    service: "smtp",
    ...result,
    message: "Email service unavailable",
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: "Route not found" });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error("express_unhandled_error", {
    requestId: req.id,
    method: req.method,
    path: req.originalUrl,
    error: err,
  });
  res.status(err.status || 500).json({
    success: false,
    message: err.status && err.status < 500 ? err.message : "Internal server error",
    ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
  });
});

const featureFlags = require("./config/feature_flags");

const PORT = process.env.PORT || 5000;
const startServer = async () => {
  await bootstrapDependencies();
  if (shouldRunBackgroundJobs) {
    startBackgroundJobs({ io });
  } else {
    logger.info("background_jobs_disabled_for_api_process");
  }
  startRoomCleanupLoop();

  return new Promise((resolve) => {
    server.listen(PORT, () => {
      logger.info("server_started", {
        port: PORT,
        apiBaseUrl: `http://localhost:${PORT}/api`,
      });
      if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
        logger.warn("smtp_not_fully_configured");
      }
      if (!process.env.SENDGRID_API_KEY && !process.env.EMAIL_PASS) {
        logger.warn("sendgrid_not_configured");
      }
      resolve(server);
    });
  });
};

// Graceful shutdown
const shutdown = async () => {
  logger.info("server_shutdown_started");
  try {
    stopBackgroundJobs();
    stopRoomCleanupLoop();
    if (typeof connectMongoDB.close === "function") {
      await connectMongoDB.close();
    }
    if (cache && typeof cache.close === 'function') {
      await cache.close();
    }
  } catch (err) {
    logger.error("server_shutdown_cleanup_error", { error: err });
  }

  server.close(() => {
    logger.info("server_shutdown_complete");
    process.exit(0);
  });

  // Force exit if server.close() takes too long
  setTimeout(() => {
    logger.error("server_force_shutdown");
    process.exit(1);
  }, 5000);
};

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

module.exports = { app, io, server, startServer };

if (require.main === module) {
  startServer().catch((error) => {
    logger.error("server_startup_failed", { error });
    process.exit(1);
  });
}
