const Chat = require('../models/Chat');
const ChatMessage = require('../models/ChatMessage');
const prisma = require('../config/prisma');
const { getIO } = require('../utils/socket');
const { sendChatNotification } = require('./fcm_service');

class ChatService {
    /**
     * Get chat conversations for a user
     * @param {string} userId 
     * @param {string} role 
     */
    async getUserChats(userId, role) {
        try {
            const query = role === 'customer' ? { customerId: userId } : role === 'rider' ? { riderId: userId } : {};

            const chats = await Chat.find(query)
                .sort({ updatedAt: -1 })
                .lean();

            // Manual hydration with User and Order data from PostgreSQL
            return await Promise.all(chats.map(async (chat) => {
                const isCustomer = chat.customerId === userId;
                const otherUserId = isCustomer ? chat.riderId : chat.customerId;

                const [otherUser, order, lastMessage, unreadCount] = await Promise.all([
                    prisma.user.findUnique({
                        where: { id: otherUserId },
                        select: { id: true, username: true, role: true, profilePicture: true }
                    }),
                    chat.orderId ? prisma.order.findUnique({
                        where: { id: chat.orderId },
                        select: { id: true, orderNumber: true }
                    }) : null,
                    ChatMessage.findOne({ chatId: chat._id }).sort({ createdAt: -1 }).lean(),
                    ChatMessage.countDocuments({
                        chatId: chat._id,
                        senderId: { $ne: userId },
                        readBy: { $ne: userId }
                    })
                ]);

                let lastMessageText = "";
                let lastMessageType = "text";
                if (lastMessage) {
                    lastMessageType = lastMessage.messageType || "text";
                    if (lastMessageType === "voice") lastMessageText = "🎤 Voice message";
                    else if (lastMessageType === "image") lastMessageText = "📷 Image";
                    else lastMessageText = lastMessage.text || "";
                }

                return {
                    id: chat._id,
                    orderId: chat.orderId,
                    orderNumber: order ? order.orderNumber : null,
                    otherUser: otherUser ? {
                        id: otherUser.id,
                        username: otherUser.username,
                        role: otherUser.role,
                        profileImage: otherUser.profilePicture
                    } : null,
                    lastMessage: lastMessageText,
                    lastMessageType: lastMessageType,
                    lastMessageAt: lastMessage ? lastMessage.createdAt : chat.updatedAt,
                    unreadCount
                };
            }));
        } catch (error) {
            console.error('❌ Error getting user chats from MongoDB:', error);
            throw error;
        }
    }

    /**
     * Get single chat with messages
     */
    async getChatWithMessages(chatId, userId, limit = 50, beforeMessageId = null) {
        try {
            const chat = await Chat.findById(chatId).lean();
            if (!chat) throw new Error('Chat not found');

            const isParticipant = chat.customerId === userId || chat.riderId === userId;
            if (!isParticipant) throw new Error('Unauthorized');

            const messageQuery = { chatId };
            if (beforeMessageId) {
                const beforeMsg = await ChatMessage.findById(beforeMessageId);
                if (beforeMsg) messageQuery.createdAt = { $lt: beforeMsg.createdAt };
            }

            const messages = await ChatMessage.find(messageQuery)
                .sort({ createdAt: -1 })
                .limit(limit)
                .lean();

            // Hydrate sender names from PostgreSQL
            const senderIds = [...new Set(messages.map(m => m.senderId))];
            const users = await prisma.user.findMany({
                where: { id: { in: senderIds } },
                select: { id: true, username: true }
            });
            const userMap = users.reduce((acc, u) => ({ ...acc, [u.id]: u.username }), {});

            // Hydrate other context
            const [customer, rider, totalCount] = await Promise.all([
                prisma.user.findUnique({ where: { id: chat.customerId }, select: { id: true, username: true, profilePicture: true } }),
                prisma.user.findUnique({ where: { id: chat.riderId }, select: { id: true, username: true, profilePicture: true } }),
                ChatMessage.countDocuments({ chatId })
            ]);

            return {
                id: chat._id,
                orderId: chat.orderId,
                customer,
                rider,
                messages: messages.map(msg => ({
                    ...msg,
                    id: msg._id,
                    senderName: userMap[msg.senderId] || 'User',
                    sentAt: msg.createdAt
                })).reverse(),
                pagination: {
                    hasMore: totalCount > messages.length,
                    totalCount,
                    returnedCount: messages.length
                }
            };
        } catch (error) {
            console.error('❌ Error getting chat messages:', error);
            throw error;
        }
    }

    /**
     * Send a message
     */
    async sendMessage(chatId, senderId, senderName, messageData) {
        try {
            const chat = await Chat.findById(chatId);
            if (!chat) throw new Error('Chat not found');

            const newMessage = new ChatMessage({
                chatId,
                senderId,
                readBy: [senderId],
                ...messageData
            });

            await newMessage.save();
            chat.updatedAt = new Date();
            await chat.save();

            // Real-time emit
            const io = getIO();
            if (io) {
                io.to(`chat:${chatId}`).emit('chat:new_message', {
                    chatId,
                    message: {
                        ...newMessage.toObject(),
                        id: newMessage._id,
                        sentAt: newMessage.createdAt
                    }
                });
            }

            // Push notification
            const recipientId = chat.customerId === senderId ? chat.riderId : chat.customerId;
            await sendChatNotification(
                recipientId,
                senderName,
                messageData.text || `Sent a ${messageData.messageType}`,
                chatId,
                messageData.messageType || 'text',
                senderId
            );

            return newMessage;
        } catch (error) {
            console.error('❌ Error sending message:', error);
            throw error;
        }
    }

    /**
     * Delete specific images from a message
     */
    async deleteMessageImages(messageId, userId, imageIndices, isAdmin = false) {
        try {
            const message = await ChatMessage.findById(messageId);
            if (!message) throw new Error('Message not found');

            // Permission check
            if (message.senderId !== userId && !isAdmin) {
                throw new Error('Unauthorized');
            }

            if (!message.imageUrls || message.imageUrls.length === 0) {
                throw new Error('Message has no images');
            }

            const sortedIndices = [...imageIndices].sort((a, b) => b - a);
            const updatedImageUrls = [...message.imageUrls];
            const updatedBlurHashes = [...(message.blurHashes || [])];

            for (const index of sortedIndices) {
                if (index >= 0 && index < updatedImageUrls.length) {
                    updatedImageUrls.splice(index, 1);
                    if (index < updatedBlurHashes.length) {
                        updatedBlurHashes.splice(index, 1);
                    }
                }
            }

            let messageDeleted = false;
            if (updatedImageUrls.length === 0) {
                await message.deleteOne();
                messageDeleted = true;
            } else {
                message.imageUrls = updatedImageUrls;
                message.blurHashes = updatedBlurHashes;
                await message.save();
            }

            const io = getIO();
            if (io) {
                io.to(`chat:${message.chatId}`).emit("chat:message_images_deleted", {
                    chatId: message.chatId,
                    messageId: message._id,
                    deletedIndices: imageIndices,
                    remainingImages: updatedImageUrls,
                    remainingBlurHashes: updatedBlurHashes,
                    messageDeleted,
                    deletedBy: userId,
                });
            }

            return { messageDeleted, remainingImages: updatedImageUrls };
        } catch (error) {
            console.error('❌ Error deleting message images:', error);
            throw error;
        }
    }
}

module.exports = new ChatService();
