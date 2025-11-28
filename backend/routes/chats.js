const express = require("express");
const Chat = require("../models/Chat");
const User = require("../models/User");
const { protect } = require("../middleware/auth");
const { io } = require("../server");
const { uploadAudioSingle, uploadAudioToCloudinary, uploadChatImages, uploadChatImagesToCloudinary } = require("../middleware/upload");
const { sendChatNotification } = require("../services/fcm_service");

const router = express.Router();

/**
 * Helper function to send push notification to the other chat participant
 * Always sends push notification - the app will handle deduplication if user is viewing the chat
 * This ensures users get notified even when app is minimized/backgrounded
 */
const notifyOfflineUser = async (chat, senderId, senderName, messagePreview, messageType = 'text') => {
  try {
    const senderIdStr = senderId.toString();

    // Get customer and rider IDs (handle both populated and non-populated cases)
    const customerId = chat.customer?._id?.toString() || chat.customer?.toString();
    const riderId = chat.rider?._id?.toString() || chat.rider?.toString();

    console.log(`📤 notifyOfflineUser: sender=${senderIdStr}, customer=${customerId}, rider=${riderId}`);

    // Determine recipient
    const recipientId = customerId === senderIdStr ? riderId : customerId;

    if (!recipientId) {
      console.log('⚠️ No recipient found for notification');
      return;
    }

    console.log(`📤 Sending push notification to ${recipientId}...`);

    // Always send push notification - FCM/app will handle showing it appropriately
    // The app's foreground handler will decide whether to show it based on current screen
    const result = await sendChatNotification(
      recipientId,
      senderName,
      messagePreview,
      chat._id.toString(),
      messageType
    );
    console.log(`📤 Push notification result:`, result);
  } catch (error) {
    console.error('Error sending offline notification:', error.message);
  }
};

// Get chat conversations for current user
router.get("/", protect, async (req, res) => {
  try {
    const userId = req.user._id;
    const userRole = req.user.role;

    const filter = {};
    if (userRole === "customer") {
      filter.customer = userId;
    } else if (userRole === "rider") {
      filter.rider = userId;
    } else if (userRole !== "admin") {
      return res.status(403).json({
        success: false,
        message:
          "Access denied. Only customers, riders, or admins can view chats.",
      });
    }

    const chats = await Chat.find(filter)
      .populate("order", "orderNumber")
      .populate("customer", "username email role")
      .populate("rider", "username email role")
      .sort({ updatedAt: -1 });

    const userIdStr = userId.toString();

    const data = chats.map((chat) => {
      const lastMessage = chat.messages[chat.messages.length - 1];
      const isCustomer =
        chat.customer && chat.customer._id.toString() === userIdStr;
      const otherUser = isCustomer ? chat.rider : chat.customer;

      const unreadCount = chat.messages.filter((msg) => {
        const sentByMe = msg.sender.toString() === userIdStr;
        const readByUser = msg.readBy.some((id) => id.toString() === userIdStr);
        return !sentByMe && !readByUser;
      }).length;

      // Determine last message display text based on type
      let lastMessageText = "";
      let lastMessageType = "text";
      if (lastMessage) {
        lastMessageType = lastMessage.messageType || "text";
        if (lastMessageType === "voice") {
          lastMessageText = "🎤 Voice message";
        } else if (lastMessageType === "image") {
          lastMessageText = "📷 Image";
        } else {
          lastMessageText = lastMessage.text || "";
        }
      }

      return {
        id: chat._id.toString(),
        orderId: chat.order ? chat.order._id.toString() : null,
        orderNumber: chat.order ? chat.order.orderNumber : null,
        otherUser: otherUser
          ? {
            id: otherUser._id.toString(),
            username: otherUser.username,
            role: otherUser.role,
          }
          : null,
        lastMessage: lastMessageText,
        lastMessageType: lastMessageType,
        lastMessageAt: lastMessage ? lastMessage.createdAt : chat.updatedAt,
        unreadCount,
      };
    });

    res.json({
      success: true,
      message: "Chats retrieved successfully",
      data,
    });
  } catch (error) {
    console.error("Get chats error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Get single chat with messages (supports pagination)
// Query params: limit (default 50), before (message ID to fetch messages before)
router.get("/:chatId", protect, async (req, res) => {
  try {
    const { chatId } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 50, 100); // Max 100 messages per request
    const beforeMessageId = req.query.before; // For loading older messages

    const chat = await Chat.findById(chatId)
      .populate("order", "orderNumber")
      .populate("customer", "username email role")
      .populate("rider", "username email role")
      .populate("messages.sender", "username email role");

    if (!chat) {
      return res.status(404).json({
        success: false,
        message: "Chat not found",
      });
    }

    const userIdStr = req.user._id.toString();
    const isParticipant =
      (chat.customer && chat.customer._id.toString() === userIdStr) ||
      (chat.rider && chat.rider._id.toString() === userIdStr) ||
      req.user.role === "admin";

    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to view this chat",
      });
    }

    // Mark messages as read by current user (only on initial load, not pagination)
    if (!beforeMessageId) {
      let changed = false;
      chat.messages.forEach((msg) => {
        const alreadyRead = msg.readBy.some((id) => id.toString() === userIdStr);
        if (!alreadyRead) {
          msg.readBy.push(req.user._id);
          changed = true;
        }
      });

      if (changed) {
        await chat.save();

        if (io) {
          io.to(`chat:${chat._id.toString()}`).emit("chat:read", {
            chatId: chat._id.toString(),
            userId: userIdStr,
            readAt: new Date().toISOString(),
          });
        }
      }
    }

    // Apply pagination - get messages before a certain message ID or get latest
    let messagesToReturn = chat.messages;
    let hasMore = false;

    if (beforeMessageId) {
      // Find the index of the message to paginate before
      const beforeIndex = chat.messages.findIndex(
        (msg) => msg._id.toString() === beforeMessageId
      );
      if (beforeIndex > 0) {
        // Get messages before this index
        const startIndex = Math.max(0, beforeIndex - limit);
        messagesToReturn = chat.messages.slice(startIndex, beforeIndex);
        hasMore = startIndex > 0;
      } else {
        messagesToReturn = [];
      }
    } else {
      // Get the latest messages
      const totalMessages = chat.messages.length;
      const startIndex = Math.max(0, totalMessages - limit);
      messagesToReturn = chat.messages.slice(startIndex);
      hasMore = startIndex > 0;
    }

    const messages = messagesToReturn.map((msg) => ({
      id: msg._id.toString(),
      messageType: msg.messageType || "text",
      text: msg.text,
      audioUrl: msg.audioUrl || null,
      audioDuration: msg.audioDuration || 0,
      imageUrls: msg.imageUrls || [],
      blurHashes: msg.blurHashes || [],
      senderId:
        msg.sender && msg.sender._id
          ? msg.sender._id.toString()
          : msg.sender.toString(),
      senderName:
        msg.sender && msg.sender.username ? msg.sender.username : undefined,
      sentAt: msg.createdAt,
      readBy: msg.readBy.map((id) => id.toString()),
      replyTo: msg.replyTo && msg.replyTo.id ? {
        id: msg.replyTo.id.toString(),
        text: msg.replyTo.text,
        senderId: msg.replyTo.senderId?.toString(),
        messageType: msg.replyTo.messageType || 'text',
      } : null,
    }));

    res.json({
      success: true,
      message: "Chat retrieved successfully",
      data: {
        id: chat._id.toString(),
        orderId: chat.order ? chat.order._id.toString() : null,
        orderNumber: chat.order ? chat.order.orderNumber : null,
        customer: chat.customer
          ? {
            id: chat.customer._id.toString(),
            username: chat.customer.username,
            role: chat.customer.role,
          }
          : null,
        rider: chat.rider
          ? {
            id: chat.rider._id.toString(),
            username: chat.rider.username,
            role: chat.rider.role,
          }
          : null,
        messages,
        pagination: {
          hasMore,
          totalCount: chat.messages.length,
          returnedCount: messages.length,
        },
      },
    });
  } catch (error) {
    console.error("Get chat error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Send a message in an existing chat
router.post("/:chatId/messages", protect, async (req, res) => {
  try {
    const { chatId } = req.params;
    const { text } = req.body;

    if (!text || !text.trim()) {
      return res.status(400).json({
        success: false,
        message: "Message text is required",
      });
    }

    const chat = await Chat.findById(chatId)
      .populate("customer", "username email role")
      .populate("rider", "username email role");

    if (!chat) {
      return res.status(404).json({
        success: false,
        message: "Chat not found",
      });
    }

    const userIdStr = req.user._id.toString();
    const isParticipant =
      (chat.customer && chat.customer._id.toString() === userIdStr) ||
      (chat.rider && chat.rider._id.toString() === userIdStr) ||
      req.user.role === "admin";

    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to send messages in this chat",
      });
    }

    const message = {
      sender: req.user._id,
      messageType: "text",
      text: text.trim(),
      createdAt: new Date(),
      readBy: [req.user._id],
    };

    // Handle reply
    const { replyToId } = req.body;
    if (replyToId) {
      const replyMessage = chat.messages.id(replyToId);
      if (replyMessage) {
        message.replyTo = {
          id: replyMessage._id,
          text: replyMessage.text,
          senderId: replyMessage.sender,
          messageType: replyMessage.messageType || 'text',
        };
      }
    }

    chat.messages.push(message);
    await chat.save();

    const savedMessage = chat.messages[chat.messages.length - 1];

    const payload = {
      chatId: chat._id.toString(),
      message: {
        id: savedMessage._id.toString(),
        messageType: savedMessage.messageType || "text",
        text: savedMessage.text,
        audioUrl: null,
        audioDuration: 0,
        senderId: savedMessage.sender.toString(),
        sentAt: savedMessage.createdAt,
        readBy: savedMessage.readBy.map((id) => id.toString()),
        replyTo: savedMessage.replyTo ? {
          id: savedMessage.replyTo.id?.toString(),
          text: savedMessage.replyTo.text,
          senderId: savedMessage.replyTo.senderId?.toString(),
          messageType: savedMessage.replyTo.messageType || 'text',
        } : null,
      },
    };

    if (io) {
      io.to(`chat:${chat._id.toString()}`).emit("chat:new_message", payload);
    }

    // Send push notification to offline user
    notifyOfflineUser(chat, req.user._id, req.user.username, text.trim(), 'text');

    res.status(201).json({
      success: true,
      message: "Message sent successfully",
      data: payload,
    });
  } catch (error) {
    console.error("Send message error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Send a voice message in an existing chat
router.post(
  "/:chatId/voice-message",
  protect,
  uploadAudioSingle("audio"),
  uploadAudioToCloudinary,
  async (req, res) => {
    try {
      const { chatId } = req.params;
      const { duration } = req.body; // Client can send duration if known

      if (!req.file || !req.file.cloudinaryUrl) {
        return res.status(400).json({
          success: false,
          message: "Audio file is required",
        });
      }

      const chat = await Chat.findById(chatId)
        .populate("customer", "username email role")
        .populate("rider", "username email role");

      if (!chat) {
        return res.status(404).json({
          success: false,
          message: "Chat not found",
        });
      }

      const userIdStr = req.user._id.toString();
      const isParticipant =
        (chat.customer && chat.customer._id.toString() === userIdStr) ||
        (chat.rider && chat.rider._id.toString() === userIdStr) ||
        req.user.role === "admin";

      if (!isParticipant) {
        return res.status(403).json({
          success: false,
          message: "Not authorized to send messages in this chat",
        });
      }

      // Use duration from Cloudinary if available, otherwise from client
      const audioDuration = req.file.duration || parseFloat(duration) || 0;

      const message = {
        sender: req.user._id,
        messageType: "voice",
        audioUrl: req.file.cloudinaryUrl,
        audioDuration: audioDuration,
        createdAt: new Date(),
        readBy: [req.user._id],
      };

      chat.messages.push(message);
      await chat.save();

      const savedMessage = chat.messages[chat.messages.length - 1];

      const payload = {
        chatId: chat._id.toString(),
        message: {
          id: savedMessage._id.toString(),
          messageType: "voice",
          text: null,
          audioUrl: savedMessage.audioUrl,
          audioDuration: savedMessage.audioDuration,
          senderId: savedMessage.sender.toString(),
          sentAt: savedMessage.createdAt,
          readBy: savedMessage.readBy.map((id) => id.toString()),
          replyTo: null,
        },
      };

      if (io) {
        io.to(`chat:${chat._id.toString()}`).emit("chat:new_message", payload);
      }

      // Send push notification to offline user
      notifyOfflineUser(chat, req.user._id, req.user.username, null, 'voice');

      res.status(201).json({
        success: true,
        message: "Voice message sent successfully",
        data: payload,
      });
    } catch (error) {
      console.error("Send voice message error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// Send image message(s) in an existing chat
router.post(
  "/:chatId/image-message",
  protect,
  uploadChatImages("images", 10),
  uploadChatImagesToCloudinary,
  async (req, res) => {
    try {
      const { chatId } = req.params;

      if (!req.uploadedImageUrls || req.uploadedImageUrls.length === 0) {
        return res.status(400).json({
          success: false,
          message: "At least one image is required",
        });
      }

      const chat = await Chat.findById(chatId)
        .populate("customer", "username email role")
        .populate("rider", "username email role");

      if (!chat) {
        return res.status(404).json({
          success: false,
          message: "Chat not found",
        });
      }

      const userIdStr = req.user._id.toString();
      const isParticipant =
        (chat.customer && chat.customer._id.toString() === userIdStr) ||
        (chat.rider && chat.rider._id.toString() === userIdStr) ||
        req.user.role === "admin";

      if (!isParticipant) {
        return res.status(403).json({
          success: false,
          message: "Not authorized to send messages in this chat",
        });
      }

      const message = {
        sender: req.user._id,
        messageType: "image",
        imageUrls: req.uploadedImageUrls,
        blurHashes: req.blurHashes || [],
        createdAt: new Date(),
        readBy: [req.user._id],
      };

      // Handle reply
      const { replyToId } = req.body;
      if (replyToId) {
        const replyMessage = chat.messages.id(replyToId);
        if (replyMessage) {
          message.replyTo = {
            id: replyMessage._id,
            text: replyMessage.messageType === 'image' ? '📷 Photo' : replyMessage.text,
            senderId: replyMessage.sender,
            messageType: replyMessage.messageType || 'text',
          };
        }
      }

      chat.messages.push(message);
      await chat.save();

      const savedMessage = chat.messages[chat.messages.length - 1];

      const payload = {
        chatId: chat._id.toString(),
        message: {
          id: savedMessage._id.toString(),
          messageType: "image",
          text: null,
          audioUrl: null,
          audioDuration: 0,
          imageUrls: savedMessage.imageUrls,
          blurHashes: savedMessage.blurHashes || [],
          senderId: savedMessage.sender.toString(),
          sentAt: savedMessage.createdAt,
          readBy: savedMessage.readBy.map((id) => id.toString()),
          replyTo: savedMessage.replyTo ? {
            id: savedMessage.replyTo.id?.toString(),
            text: savedMessage.replyTo.text,
            senderId: savedMessage.replyTo.senderId?.toString(),
            messageType: savedMessage.replyTo.messageType || 'text',
          } : null,
        },
      };

      if (io) {
        io.to(`chat:${chat._id.toString()}`).emit("chat:new_message", payload);
      }

      // Send push notification to offline user
      notifyOfflineUser(chat, req.user._id, req.user.username, null, 'image');

      res.status(201).json({
        success: true,
        message: "Image message sent successfully",
        data: payload,
      });
    } catch (error) {
      console.error("Send image message error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// Delete a message from a chat
router.delete("/:chatId/messages/:messageId", protect, async (req, res) => {
  try {
    const { chatId, messageId } = req.params;

    const chat = await Chat.findById(chatId);

    if (!chat) {
      return res.status(404).json({
        success: false,
        message: "Chat not found",
      });
    }

    const userIdStr = req.user._id.toString();
    const isParticipant =
      (chat.customer && chat.customer.toString() === userIdStr) ||
      (chat.rider && chat.rider.toString() === userIdStr) ||
      req.user.role === "admin";

    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to delete messages in this chat",
      });
    }

    // Find the message
    const messageIndex = chat.messages.findIndex(
      (msg) => msg._id.toString() === messageId
    );

    if (messageIndex === -1) {
      return res.status(404).json({
        success: false,
        message: "Message not found",
      });
    }

    const message = chat.messages[messageIndex];

    // Only allow sender or admin to delete
    if (message.sender.toString() !== userIdStr && req.user.role !== "admin") {
      return res.status(403).json({
        success: false,
        message: "You can only delete your own messages",
      });
    }

    // Remove the message
    chat.messages.splice(messageIndex, 1);
    await chat.save();

    // Emit socket event for real-time sync
    if (io) {
      io.to(`chat:${chat._id.toString()}`).emit("chat:message_deleted", {
        chatId: chat._id.toString(),
        messageId: messageId,
        deletedBy: userIdStr,
      });
    }

    res.json({
      success: true,
      message: "Message deleted successfully",
      data: {
        chatId: chat._id.toString(),
        messageId: messageId,
      },
    });
  } catch (error) {
    console.error("Delete message error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

module.exports = router;
