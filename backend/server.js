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
    console.log(`✅ User ${userId} joined notification room`);
  }

  socket.on("chat:join", async ({ chatId }) => {
    try {
      const userId = socket.data.userId;
      if (!chatId || !userId) return;

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

  socket.on("chat:typing", ({ chatId, isTyping }) => {
    const userId = socket.data.userId;
    if (!chatId || !userId) return;
    const userIdStr = userId.toString();
    const room = `chat:${chatId}`;
    socket.to(room).emit("chat:typing", {
      chatId,
      userId: userIdStr,
      isTyping: !!isTyping,
    });
  });

  socket.on("chat:mark_read", async ({ chatId }) => {
    try {
      const userId = socket.data.userId;
      if (!chatId || !userId) return;

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

  // Join order tracking room (for customers tracking their orders)
  socket.on("join_order", ({ orderId }) => {
    if (!orderId) {
      console.warn("⚠️ join_order: No orderId provided");
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
  });

  // Leave order tracking room
  socket.on("leave_order", ({ orderId }) => {
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

    try {
      // Update rider's online status in MongoDB RiderStatus
      const RiderStatus = require('./models/RiderStatus');
      const { latitude, longitude, batteryLevel, isCharging } = data || {};

      // Use provided location or default
      const lat = latitude || 5.6037;
      const lon = longitude || -0.187;
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

    const { latitude, longitude, batteryLevel, isCharging } = data || {};
    if (!latitude || !longitude) return;

    try {
      // Update location in MongoDB RiderStatus
      const RiderStatus = require('./models/RiderStatus');

      const updateData = {
        'location.coordinates': [parseFloat(longitude), parseFloat(latitude)],
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
  socket.on("reservation:respond", async ({ reservationId, action, declineReason }) => {
    const userId = socket.data.userId;
    const userRole = socket.data.userRole;

    if (userRole !== 'rider') {
      socket.emit('reservation:response', {
        success: false,
        error: 'Only riders can respond to reservations'
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
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Serve uploaded files
app.use("/uploads", express.static("uploads"));

// Routes
app.use("/api/users", require("./routes/auth"));
app.use("/api/users", require("./routes/notification_settings"));
app.use("/api/restaurants", require("./routes/restaurants"));
app.use("/api/orders", require("./routes/orders"));
app.use("/api/payments", require("./routes/payments"));
app.use("/api/categories", require("./routes/categories"));
app.use("/api/foods", require("./routes/foods"));
app.use("/api/groceries", require("./routes/groceries"));
app.use("/api/pharmacies", require("./routes/pharmacies"));
app.use("/api/grabmart", require("./routes/grabmart"));
app.use("/api/riders", require("./routes/riders"));
app.use("/api/rider-analytics", require("./routes/rider_analytics"));
app.use("/api/chats", require("./routes/chats"));
app.use("/api/statuses", require("./routes/statuses"));
app.use("/api/notifications", require("./routes/notifications"));
app.use("/api/scheduled-notifications", require("./routes/scheduled_notifications"));
app.use("/api/referral", require("./routes/referrals"));
app.use("/api/promotions", require("./routes/promotions"));
app.use("/api/cart", require("./routes/cart"));
app.use("/api/favorites", require("./routes/favorites"));
app.use("/api/promo", require("./routes/promo"));
app.use("/api/test", require("./routes/test"));
app.use("/api/tracking", require("./routes/tracking_routes"));
app.use("/api/credits", require("./routes/credits"));
app.use("/api/addresses", require("./routes/address"));
app.use('/api/calls', callRoutes);

app.set('webrtcSignaling', webrtcSignaling);

// Health check
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", message: "GrabGo API is running" });
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
const { scheduleCleanup } = require("./jobs/statusCleanup");
const { scheduleReferralCleanup } = require("./jobs/referralCleanup");
const { initializeScheduler } = require("./jobs/notification_scheduler");
const { initializeCartAbandonmentJob } = require("./jobs/cart_abandonment");
const { initializeMealNudges } = require("./jobs/meal_nudges");
const { initializeEngagementNudges } = require("./jobs/engagement_nudges");
const reservationExpiryJob = require("./jobs/reservation_expiry");
const { runAutoOfflineJob } = require("./jobs/rider_auto_offline");
const { initializeDeliveryMonitor } = require("./jobs/delivery_monitor");

// Import cache utility
const cache = require("./utils/cache");

// Initialize Redis cache (optional - falls back to memory cache)
cache.initRedis();

// Schedule status cleanup cron job (runs every hour)
scheduleCleanup();

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

// Initialize delivery monitor (runs every minute - warns riders, notifies customers)
initializeDeliveryMonitor();

// Schedule rider auto-offline job (runs every 5 minutes)
setInterval(() => {
  runAutoOfflineJob().catch(err => console.error('Auto-offline job error:', err));
}, 5 * 60 * 1000);
// Run once at startup after a delay
setTimeout(() => {
  runAutoOfflineJob().catch(err => console.error('Auto-offline job startup error:', err));
}, 10000);

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 API available at http://localhost:${PORT}/api`);
  if (!process.env.EMAIL_PASS) {
    console.log("⚠️  Email service not configured");
  }
});

// Graceful shutdown
const shutdown = async () => {
  console.log("🛑 Shutting down server...");
  try {
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
