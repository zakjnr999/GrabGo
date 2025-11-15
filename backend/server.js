const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const compression = require("compression");
const http = require("http");
const { Server } = require("socket.io");
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

module.exports = { app, io };

io.on("connection", (socket) => {
  console.log("🔌 New WebSocket connection", socket.id);

  socket.on("chat:join", ({ chatId, userId }) => {
    if (!chatId) return;

    const room = `chat:${chatId}`;
    socket.join(room);

    // Track which user and chats this socket is associated with
    if (userId) {
      socket.data.userId = userId;
    }
    if (!socket.data.chats) {
      socket.data.chats = new Set();
    }
    socket.data.chats.add(room);

    if (userId) {
      socket.to(room).emit("chat:presence", { chatId, userId, online: true });
    }
  });

  socket.on("chat:typing", ({ chatId, userId, isTyping }) => {
    if (!chatId || !userId) return;
    const room = `chat:${chatId}`;
    socket.to(room).emit("chat:typing", {
      chatId,
      userId,
      isTyping: !!isTyping,
    });
  });

  socket.on("disconnect", () => {
    const userId = socket.data.userId;
    const chats = socket.data.chats;

    if (userId && chats && typeof chats.forEach === "function") {
      chats.forEach((room) => {
        const chatId = room.replace("chat:", "");
        socket
          .to(room)
          .emit("chat:presence", { chatId, userId, online: false });
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
