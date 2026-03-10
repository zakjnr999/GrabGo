const express = require("express");
const { protect } = require("../middleware/auth");
const { chatMessageRateLimit, chatMediaRateLimit } = require("../middleware/fraud_rate_limit");
const { createScopedLogger } = require("../utils/logger");
const { getIO } = require("../utils/socket");
const { uploadAudioSingle, uploadAudioToCloudinary, uploadChatImages, uploadChatImagesToCloudinary } = require("../middleware/upload");
const ChatService = require("../services/chat_service");
const Chat = require("../models/Chat");
const ChatMessage = require("../models/ChatMessage");

const router = express.Router();
const console = createScopedLogger("chats_route");

const getChatErrorStatus = (error, fallbackStatus = 500) => {
  const explicitStatus = Number(error?.status);
  if (Number.isInteger(explicitStatus) && explicitStatus >= 400 && explicitStatus < 600) {
    return explicitStatus;
  }

  switch (String(error?.message || "")) {
    case "Unauthorized":
      return 403;
    case "Chat not found":
    case "Message not found":
      return 404;
    case "Message has no images":
      return 400;
    default:
      return fallbackStatus;
  }
};

const sendChatError = (res, error, fallbackMessage, fallbackStatus = 500) => {
  const status = getChatErrorStatus(error, fallbackStatus);
  const safeMessage = status >= 500 ? fallbackMessage : String(error?.message || fallbackMessage);

  return res.status(status).json({
    success: false,
    message: safeMessage,
  });
};

/**
 * @route   GET /api/chats
 * @desc    Get user conversations (MongoDB + Postgres Hydration)
 */
router.get("/", protect, async (req, res) => {
  try {
    const data = await ChatService.getUserChats(req.user.id, req.user.role);
    res.json({ success: true, message: "Chats retrieved successfully", data });
  } catch (error) {
    console.error("Get chats error:", error);
    return sendChatError(res, error, "Server error");
  }
});

/**
 * @route   GET /api/chats/:chatId
 * @desc    Get single chat with messages
 */
router.get("/:chatId", protect, async (req, res) => {
  try {
    const { chatId } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const beforeMessageId = req.query.before;

    const data = await ChatService.getChatWithMessages(chatId, req.user.id, limit, beforeMessageId);

    // Mark as read in background if not paginating
    if (!beforeMessageId) {
      ChatService.markAsRead(chatId, req.user.id);
    }

    res.json({ success: true, message: "Chat retrieved successfully", data });
  } catch (error) {
    console.error("Get chat error:", error);
    if (String(error?.message || "") === "Chat not found") {
      return res.status(404).json({
        success: false,
        message: "Chat not found",
      });
    }

    return sendChatError(res, error, "Server error");
  }
});

/**
 * @route   POST /api/chats/:chatId/messages
 * @desc    Send text message
 */
router.post("/:chatId/messages", protect, chatMessageRateLimit, async (req, res) => {
  try {
    const { chatId } = req.params;
    const { text, replyToId } = req.body;

    if (!text || !text.trim()) {
      return res.status(400).json({ success: false, message: "Message text is required" });
    }

    const messageData = {
      messageType: 'text',
      text: text.trim()
    };

    if (replyToId) {
      const replyMsg = await ChatMessage.findById(replyToId);
      if (replyMsg) {
        messageData.replyToId = replyMsg._id;
        messageData.replyToText = replyMsg.text;
        messageData.replyToSenderId = replyMsg.senderId;
        messageData.replyToMessageType = replyMsg.messageType;
      }
    }

    const savedMessage = await ChatService.sendMessage(chatId, req.user.id, req.user.username, messageData);

    res.status(201).json({
      success: true,
      message: "Message sent successfully",
      data: { chatId, message: savedMessage }
    });
  } catch (error) {
    console.error("Send message error:", error);
    return sendChatError(res, error, "Server error");
  }
});

/**
 * @route   POST /api/chats/:chatId/voice-message
 * @desc    Send voice message
 */
router.post("/:chatId/voice-message", protect, chatMediaRateLimit, uploadAudioSingle("audio"), uploadAudioToCloudinary, async (req, res) => {
  try {
    const { chatId } = req.params;
    const { duration } = req.body;

    if (!req.file || !req.file.cloudinaryUrl) {
      return res.status(400).json({ success: false, message: "Audio file is required" });
    }

    const messageData = {
      messageType: "voice",
      audioUrl: req.file.cloudinaryUrl,
      audioDuration: Math.round(req.file.duration || parseFloat(duration) || 0)
    };

    const savedMessage = await ChatService.sendMessage(chatId, req.user.id, req.user.username, messageData);

    res.status(201).json({ success: true, message: "Voice message sent successfully", data: { chatId, message: savedMessage } });
  } catch (error) {
    console.error("Send voice message error:", error);
    return sendChatError(res, error, "Server error");
  }
});

/**
 * @route   POST /api/chats/:chatId/image-message
 * @desc    Send image message
 */
router.post("/:chatId/image-message", protect, chatMediaRateLimit, uploadChatImages("images", 10), uploadChatImagesToCloudinary, async (req, res) => {
  try {
    const { chatId } = req.params;
    const { replyToId } = req.body;

    if (!req.uploadedImageUrls || req.uploadedImageUrls.length === 0) {
      return res.status(400).json({ success: false, message: "At least one image is required" });
    }

    const messageData = {
      messageType: "image",
      imageUrls: req.uploadedImageUrls,
      blurHashes: req.blurHashes || []
    };

    if (replyToId) {
      const replyMsg = await ChatMessage.findById(replyToId);
      if (replyMsg) {
        messageData.replyToId = replyMsg._id;
        messageData.replyToText = replyMsg.messageType === 'image' ? '📷 Photo' : replyMsg.text;
        messageData.replyToSenderId = replyMsg.senderId;
        messageData.replyToMessageType = replyMsg.messageType;
      }
    }

    const savedMessage = await ChatService.sendMessage(chatId, req.user.id, req.user.username, messageData);

    res.status(201).json({ success: true, message: "Image message sent successfully", data: { chatId, message: savedMessage } });
  } catch (error) {
    console.error("Send image message error:", error);
    return sendChatError(res, error, "Server error");
  }
});

/**
 * @route   DELETE /api/chats/:chatId/messages/:messageId
 * @desc    Delete message
 */
router.delete("/:chatId/messages/:messageId", protect, async (req, res) => {
  try {
    const { chatId, messageId } = req.params;
    const message = await ChatMessage.findById(messageId);

    if (!message || message.chatId.toString() !== chatId) {
      return res.status(404).json({ success: false, message: "Message not found" });
    }

    if (message.senderId !== req.user.id && req.user.role !== "admin") {
      return res.status(403).json({ success: false, message: "Unauthorized" });
    }

    await message.deleteOne();

    const io = getIO();
    if (io) {
      io.to(`chat:${chatId}`).emit("chat:message_deleted", { chatId, messageId, deletedBy: req.user.id });
    }

    res.json({ success: true, message: "Message deleted successfully", data: { chatId, messageId } });
  } catch (error) {
    console.error("Delete message error:", error);
    return sendChatError(res, error, "Server error");
  }
});

/**
 * @route   PUT /api/chats/:chatId/messages/:messageId
 * @desc    Edit text message
 */
router.put("/:chatId/messages/:messageId", protect, async (req, res) => {
  try {
    const { chatId, messageId } = req.params;
    const { text } = req.body;

    if (!text || text.trim().length === 0) {
      return res.status(400).json({ success: false, message: "Text is required" });
    }

    const message = await ChatMessage.findById(messageId);
    if (!message || message.chatId.toString() !== chatId) {
      return res.status(404).json({ success: false, message: "Message not found" });
    }

    if (message.senderId !== req.user.id) {
      return res.status(403).json({ success: false, message: "Unauthorized" });
    }

    if (message.messageType !== 'text') {
      return res.status(400).json({ success: false, message: "Only text messages can be edited" });
    }

    message.text = text.trim();
    message.isEdited = true;
    message.editedAt = new Date();
    await message.save();

    const io = getIO();
    if (io) {
      io.to(`chat:${chatId}`).emit("chat:message_edited", {
        chatId,
        messageId,
        newText: message.text,
        editedAt: message.editedAt,
        editedBy: req.user.id
      });
    }

    res.json({ success: true, message: "Message edited successfully", data: { chatId, messageId, text: message.text, isEdited: true } });
  } catch (error) {
    console.error("Edit message error:", error);
    return sendChatError(res, error, "Server error");
  }
});

/**
 * @route   POST /api/chats/:chatId/messages/:messageId/delete-images
 * @desc    Delete specific images from a message
 */
router.post("/:chatId/messages/:messageId/delete-images", protect, async (req, res) => {
  try {
    const { chatId, messageId } = req.params;
    let { imageIndices } = req.body;

    // Support both body and query params
    if (!imageIndices && req.query.indices) {
      imageIndices = req.query.indices.split(',').map(Number);
    }

    if (!imageIndices || !Array.isArray(imageIndices) || imageIndices.length === 0) {
      return res.status(400).json({ success: false, message: "imageIndices array is required" });
    }

    const result = await ChatService.deleteMessageImages(
      messageId,
      req.user.id,
      imageIndices,
      req.user.role === 'admin'
    );

    res.json({
      success: true,
      message: result.messageDeleted ? "All images deleted, message removed" : `${imageIndices.length} image(s) deleted successfully`,
      data: { chatId, messageId, ...result }
    });
  } catch (error) {
    console.error("Delete images error:", error);
    return sendChatError(res, error, "Server error");
  }
});

module.exports = router;
