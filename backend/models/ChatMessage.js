const mongoose = require('mongoose');

const chatMessageSchema = new mongoose.Schema({
    chatId: {
        type: String, // References PostgreSQL Chat ID
        required: true,
        index: true
    },
    senderId: {
        type: String, // References PostgreSQL User ID
        required: true
    },
    text: String,
    imageUrl: String,
    voiceUrl: String,
    messageType: {
        type: String,
        enum: ['text', 'voice', 'image'],
        default: 'text'
    },
    readBy: [{
        type: String // List of User IDs
    }],
    metadata: mongoose.Schema.Types.Mixed
}, {
    timestamps: true
});

chatMessageSchema.index({ createdAt: 1 });

module.exports = mongoose.model('ChatMessage', chatMessageSchema);
