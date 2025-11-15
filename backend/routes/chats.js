const express = require("express");
const Chat = require("../models/Chat");
const { protect } = require("../middleware/auth");

const router = express.Router();

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
        lastMessage: lastMessage ? lastMessage.text : "",
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

// Get single chat with messages
router.get("/:chatId", protect, async (req, res) => {
  try {
    const { chatId } = req.params;

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

    // Mark messages as read by current user
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
    }

    const messages = chat.messages.map((msg) => ({
      id: msg._id.toString(),
      text: msg.text,
      senderId:
        msg.sender && msg.sender._id
          ? msg.sender._id.toString()
          : msg.sender.toString(),
      senderName:
        msg.sender && msg.sender.username ? msg.sender.username : undefined,
      sentAt: msg.createdAt,
      readBy: msg.readBy.map((id) => id.toString()),
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
      text: text.trim(),
      createdAt: new Date(),
      readBy: [req.user._id],
    };

    chat.messages.push(message);
    await chat.save();

    const savedMessage = chat.messages[chat.messages.length - 1];

    res.status(201).json({
      success: true,
      message: "Message sent successfully",
      data: {
        chatId: chat._id.toString(),
        message: {
          id: savedMessage._id.toString(),
          text: savedMessage.text,
          senderId: savedMessage.sender.toString(),
          sentAt: savedMessage.createdAt,
        },
      },
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

module.exports = router;
