const mongoose = require('mongoose');

const chatMessageSchema = new mongoose.Schema({
    chatId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Chat',
        required: true,
        index: true
    },
    senderId: {
        type: String,
        required: true
    },
    text: String,
    messageType: {
        type: String,
        enum: ['text', 'voice', 'image'],
        default: 'text'
    },
    audioUrl: String,
    audioDuration: {
        type: Number,
        default: 0
    },
    imageUrls: {
        type: [String],
        default: []
    },
    blurHashes: {
        type: [String],
        default: []
    },
    readBy: [{
        type: String
    }],
    replyTo: {
        id: String,
        text: String,
        senderId: String,
        messageType: { type: String, enum: ['text', 'voice', 'image'], default: 'text' }
    },
    metadata: mongoose.Schema.Types.Mixed
}, {
    timestamps: true
});

chatMessageSchema.index({ createdAt: 1 });

module.exports = mongoose.model('ChatMessage', chatMessageSchema);
