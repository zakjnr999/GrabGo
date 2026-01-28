const mongoose = require('mongoose');

const chatMessageSchema = new mongoose.Schema({
    chatId: {
        type: mongoose.Schema.Types.ObjectId, // References MongoDB Chat
        ref: 'Chat',
        required: true,
        index: true
    },
    senderId: {
        type: String, // References PostgreSQL User ID
        required: true
    },
    text: String,
    messageType: {
        type: String,
        enum: ['text', 'voice', 'image'],
        default: 'text'
    },
    // Voice message fields
    audioUrl: String,
    audioDuration: {
        type: Number, // Duration in seconds
        default: 0
    },
    // Image message fields (supports multiple images)
    imageUrls: {
        type: [String],
        default: []
    },
    // BlurHash for instant image previews (one per image)
    blurHashes: {
        type: [String],
        default: []
    },
    readBy: [{
        type: String // List of User IDs
    }],
    // Reply reference
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
