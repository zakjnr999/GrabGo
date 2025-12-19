const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const compression = require("compression");
const http = require("http");
const { Server } = require("socket.io");
const jwt = require("jsonwebtoken");
const User = require("./models/User");
const Chat = require("./models/Chat");
require("dotenv").config();

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(",") || "*",
    methods: ["GET", "POST"],
    credentials: true,
  },
});

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
    const user = await User.findById(decoded.id).select("_id role isActive");

    if (!user || !user.isActive) {
      return next(new Error("Not authorized"));
    }

    socket.data.userId = user._id.toString();
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

      const chat = await Chat.findById(chatId).select("customer rider");
      if (!chat) return;

      const userIdStr = userId.toString();
      const isParticipant =
        (chat.customer && chat.customer.toString() === userIdStr) ||
        (chat.rider && chat.rider.toString() === userIdStr);

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
      const otherUserId = chat.customer?.toString() === userIdStr
        ? chat.rider?.toString()
        : chat.customer?.toString();

      if (otherUserId) {
        const otherPresenceKey = `${chatId}:${otherUserId}`;
        const otherCount = chatPresence.get(otherPresenceKey) || 0;

        // Also verify the user actually has connected sockets in this room
        const socketsInRoom = await io.in(room).fetchSockets();
        const otherUserHasSocket = socketsInRoom.some(
          (s) => s.data.userId?.toString() === otherUserId && s.id !== socket.id
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
          const otherUser = await User.findById(otherUserId).select("lastSeenAt");
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

      const chat = await Chat.findById(chatId);
      if (!chat) return;

      const userIdStr = userId.toString();
      const isParticipant =
        (chat.customer && chat.customer.toString() === userIdStr) ||
        (chat.rider && chat.rider.toString() === userIdStr);

      if (!isParticipant) return;

      let changed = false;
      chat.messages.forEach((msg) => {
        const alreadyRead = msg.readBy.some((id) => id.toString() === userIdStr);
        if (!alreadyRead) {
          msg.readBy.push(userId);
          changed = true;
        }
      });

      if (changed) {
        await chat.save();
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
        await User.findByIdAndUpdate(userId, { lastSeenAt });
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

    console.log("🔌 WebSocket disconnected", socket.id);
  });
});

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
app.use("/api/riders", require("./routes/riders"));
app.use("/api/chats", require("./routes/chats"));
app.use("/api/statuses", require("./routes/statuses"));
app.use("/api/notifications", require("./routes/notifications"));
app.use("/api/scheduled-notifications", require("./routes/scheduled_notifications"));
app.use("/api/referral", require("./routes/referrals"));
app.use("/api/promotions", require("./routes/promotions"));
app.use("/api/cart", require("./routes/cart"));

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

// Import cache utility
const cache = require("./utils/cache");

// Connect to MongoDB
mongoose
  .connect(process.env.MONGODB_URI || "mongodb://localhost:27017/grabgo")
  .then(() => {
    console.log("✅ Connected to MongoDB");

    // Initialize Redis cache (optional - falls back to memory cache)
    cache.initRedis();

    // Schedule status cleanup cron job (runs every hour)
    scheduleCleanup();

    // Schedule referral cleanup cron job (runs daily at 2:00 AM)
    scheduleReferralCleanup();

    // Initialize notification scheduler (runs every minute)
    initializeScheduler(io);

    const PORT = process.env.PORT || 5000;
    server.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📡 API available at http://localhost:${PORT}/api`);
      if (!process.env.EMAIL_PASS) {
        console.log("⚠️  Email service not configured");
      }
    });
  })
  .catch((error) => {
    console.error(" MongoDB connection error:", error);
    process.exit(1);
  });

// Graceful shutdown
process.on("SIGTERM", async () => {
  console.log("SIGTERM received, shutting down gracefully...");
  await cache.close();
  process.exit(0);
});

process.on("SIGINT", async () => {
  console.log("SIGINT received, shutting down gracefully...");
  await cache.close();
  process.exit(0);
});
