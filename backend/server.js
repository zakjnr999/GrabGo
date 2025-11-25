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

  socket.on("chat:join", async ({ chatId }) => {
    try {
      const userId = socket.data.userId;
      console.log(`[Socket] chat:join received: chatId=${chatId}, userId=${userId}`);
      if (!chatId || !userId) return;

      const chat = await Chat.findById(chatId).select("customer rider");
      if (!chat) {
        console.log(`[Socket] chat:join - chat not found: ${chatId}`);
        return;
      }

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
      console.log(`[Socket] User ${userIdStr} joined room ${room}`);

      if (!socket.data.chats) {
        socket.data.chats = new Set();
      }
      socket.data.chats.add(room);

      const presenceKey = `${chatId}:${userIdStr}`;
      const previousCount = chatPresence.get(presenceKey) || 0;
      const nextCount = previousCount + 1;
      chatPresence.set(presenceKey, nextCount);

      if (previousCount === 0) {
        socket.to(room).emit("chat:presence", { chatId, userId: userIdStr, online: true });
      }
    } catch (error) {
      console.error("chat:join error:", error.message);
    }
  });

  socket.on("chat:typing", ({ chatId, isTyping }) => {
    const userId = socket.data.userId;
    console.log(`[Socket] chat:typing received: chatId=${chatId}, userId=${userId}, isTyping=${isTyping}`);
    if (!chatId || !userId) {
      console.log(`[Socket] chat:typing skipped - missing chatId or userId`);
      return;
    }
    const userIdStr = userId.toString();
    const room = `chat:${chatId}`;
    const roomSockets = io.sockets.adapter.rooms.get(room);
    console.log(`[Socket] Emitting chat:typing to room ${room}, sockets in room: ${roomSockets ? roomSockets.size : 0}`);
    socket.to(room).emit("chat:typing", {
      chatId,
      userId: userIdStr,
      isTyping: !!isTyping,
    });
  });

  socket.on("disconnect", () => {
    const userId = socket.data.userId;
    const chats = socket.data.chats;

    if (userId && chats && typeof chats.forEach === "function") {
      const userIdStr = userId.toString();
      chats.forEach((room) => {
        const chatId = room.replace("chat:", "");
        const presenceKey = `${chatId}:${userIdStr}`;
        const previousCount = chatPresence.get(presenceKey) || 0;
        const nextCount = previousCount - 1;

        if (nextCount <= 0) {
          chatPresence.delete(presenceKey);
          socket
            .to(room)
            .emit("chat:presence", { chatId, userId: userIdStr, online: false });
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
app.use("/api/restaurants", require("./routes/restaurants"));
app.use("/api/orders", require("./routes/orders"));
app.use("/api/payments", require("./routes/payments"));
app.use("/api/categories", require("./routes/categories"));
app.use("/api/foods", require("./routes/foods"));
app.use("/api/riders", require("./routes/riders"));
app.use("/api/chats", require("./routes/chats"));

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

// Connect to MongoDB
mongoose
  .connect(process.env.MONGODB_URI || "mongodb://localhost:27017/grabgo")
  .then(() => {
    console.log("✅ Connected to MongoDB");
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
