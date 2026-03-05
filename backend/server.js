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
require("dotenv").config();

// Connect to MongoDB for NoSQL data (Hybrid Architecture)
connectMongoDB();

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
    methods: ["GET", "POST"],
    credentials: true,
  },
});

// Initialize Socket.IO singleton for global access
initIO(io);
app.set('io', io);

// Initialize WebRTC signaling
const webrtcSignaling = new WebRTCSignalingService(io);

console.log("✅ WebRTC signaling service initialized");

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

module.exports = { app, io };

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
        error: error.message
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
      socket.emit('reservation:active', { reservation: null, error: error.message });
    }
  });
});

// SECURITY: Periodic cleanup of empty rooms (every hour)
setInterval(() => {
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
    console.log(`🧹 Periodic cleanup: removed ${cleanedCount} empty notification rooms`);
  }
}, 3600000); // Every hour

// Middleware
app.use(helmet());
app.use(compression());
app.use(morgan("dev"));
app.use(
  cors({
    origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
    credentials: true,
  })
);
// Raw parser for payment webhook signature verification.
app.use("/api/payments/webhooks/paystack", express.raw({ type: "application/json" }));
app.use("/api/subscriptions/webhook", express.raw({ type: "application/json" }));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));
app.use("/api", apiGlobalRateLimit);

// Serve uploaded files
app.use("/uploads", express.static("uploads"));

// Routes
app.use("/api/users", require("./routes/auth"));
app.use("/api/users", require("./routes/notification_settings"));
app.use("/api/restaurants", require("./routes/restaurants"));
app.use("/api/orders", require("./routes/orders"));
app.use("/api/checkout-sessions", require("./routes/checkout_sessions"));
app.use("/api/payments", require("./routes/payments"));
app.use("/api/fraud", require("./routes/fraud"));
app.use("/api/admin/fraud", require("./routes/admin_fraud"));
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
app.use("/api/cart", require("./routes/cart"));
app.use("/api/favorites", require("./routes/favorites"));
app.use("/api/promo", require("./routes/promo"));
app.use("/api/parcel", require("./routes/parcel"));
app.use("/api/test", require("./routes/test"));
app.use("/api/tracking", require("./routes/tracking_routes"));
app.use("/api/credits", require("./routes/credits"));
app.use("/api/subscriptions", require("./routes/subscriptions"));
app.use("/api/addresses", require("./routes/address"));
app.use('/api/calls', callRoutes);

app.set('webrtcSignaling', webrtcSignaling);

// Health check
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", message: "GrabGo API is running" });
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
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: "Route not found" });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || "Internal server error",
    ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
  });
});

// Import cron jobs
const { scheduleReferralCleanup } = require("./jobs/referralCleanup");
const { initializeScheduler } = require("./jobs/notification_scheduler");
const { initializeCartAbandonmentJob } = require("./jobs/cart_abandonment");
const { initializeMealNudges } = require("./jobs/meal_nudges");
const { initializeEngagementNudges } = require("./jobs/engagement_nudges");
const reservationExpiryJob = require("./jobs/reservation_expiry");
const { runAutoOfflineJob } = require("./jobs/rider_auto_offline");
const { initializeDeliveryMonitor } = require("./jobs/delivery_monitor");
const { initializePickupAcceptTimeoutJob } = require("./jobs/pickup_accept_timeout");
const { initializePickupReadyExpiryJob } = require("./jobs/pickup_ready_expiry");
const { initializeScheduledOrderReleaseJob } = require("./jobs/scheduled_order_release");
const dispatchRetryQueueJob = require("./jobs/dispatch_retry_queue");
const { startFraudOutboxWorker, stopFraudOutboxWorker } = require("./jobs/fraud_outbox_worker");
const {
  startFraudFeatureRecomputeJob,
  stopFraudFeatureRecomputeJob,
} = require("./jobs/fraud_feature_recompute");
const { fraudPolicyService } = require("./services/fraud");
const featureFlags = require("./config/feature_flags");
const { scheduleRiderPartnerRecalc } = require("./jobs/rider_partner_recalc");
const { scheduleIncentiveBudgetApproval } = require("./jobs/incentive_budget_approval");
const { scheduleWeeklyPayout } = require("./jobs/rider_weekly_payout");
const { scheduleLoanDailyRepayment } = require("./jobs/loan_daily_repayment");

// Initialize Redis cache (optional - falls back to memory cache)
cache.initRedis();
fraudPolicyService.ensureDefaultPolicy().catch((error) => {
  console.error("[Fraud] Default policy bootstrap failed:", error.message);
});

// Schedule referral cleanup cron job (runs daily at 2:00 AM)
scheduleReferralCleanup();

// Initialize notification scheduler (runs every minute)
initializeScheduler(io);

// Initialize cart abandonment job (runs every 30 minutes)
initializeCartAbandonmentJob(io);

// Initialize meal-time nudges (breakfast, lunch, dinner)
initializeMealNudges(io);

// Initialize engagement nudges (favorites, reorder, re-engagement)
initializeEngagementNudges(io);

// Initialize order reservation expiry job (runs every 2 seconds)
reservationExpiryJob.start();

// Initialize dispatch retry queue worker (handles durable re-dispatch for unassigned orders)
dispatchRetryQueueJob.start();

// Initialize delivery monitor (runs every minute - warns riders, notifies customers)
initializeDeliveryMonitor();

// Initialize pickup lifecycle jobs (runs every minute)
initializePickupAcceptTimeoutJob(io);
initializePickupReadyExpiryJob(io);
initializeScheduledOrderReleaseJob(io);
if (featureFlags.isFraudEnabled && featureFlags.isFraudOutboxWorkerEnabled) {
  startFraudOutboxWorker();
  startFraudFeatureRecomputeJob();
}

// Schedule rider auto-offline job (runs every 5 minutes)
setInterval(() => {
  runAutoOfflineJob().catch(err => console.error('Auto-offline job error:', err));
}, 5 * 60 * 1000);
// Run once at startup after a delay
setTimeout(() => {
  runAutoOfflineJob().catch(err => console.error('Auto-offline job startup error:', err));
}, 10000);

// Schedule rider partner score recalculation (daily at 02:00 Africa/Accra)
if (featureFlags.isRiderPartnerSystemEnabled || featureFlags.isRiderPartnerShadowMode) {
  scheduleRiderPartnerRecalc();
}

// Schedule incentive budget approval (every 5 minutes)
if (featureFlags.isRiderIncentivesEnabled) {
  scheduleIncentiveBudgetApproval();
}

// Schedule weekly auto-payout (Monday 06:00 Africa/Accra)
if (featureFlags.isRiderIncentivesEnabled) {
  scheduleWeeklyPayout();
}

// Schedule daily loan repayments (04:00 Africa/Accra)
scheduleLoanDailyRepayment();

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 API available at http://localhost:${PORT}/api`);
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
    console.log("⚠️  Email service (SMTP) not fully configured");
  }
  if (!process.env.SENDGRID_API_KEY && !process.env.EMAIL_PASS) {
    console.log("⚠️  SendGrid not configured (used only for legacy email-to-SMS)");
  }
});

// Graceful shutdown
const shutdown = async () => {
  console.log("🛑 Shutting down server...");
  try {
    if (featureFlags.isFraudEnabled && featureFlags.isFraudOutboxWorkerEnabled) {
      stopFraudOutboxWorker();
      stopFraudFeatureRecomputeJob();
    }
    if (cache && typeof cache.close === 'function') {
      await cache.close();
    }
  } catch (err) {
    console.error("Error closing cache:", err.message);
  }

  server.close(() => {
    console.log("🏁 Server closed");
    process.exit(0);
  });

  // Force exit if server.close() takes too long
  setTimeout(() => {
    console.error("⚠️ Forcefully shutting down...");
    process.exit(1);
  }, 5000);
};

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
