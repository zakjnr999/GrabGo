const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
    {
        sender: {
            type: String, // String reference to PostgreSQL User ID
            required: true,
        },
        messageType: {
            type: String,
            enum: ["text", "voice", "image"],
            default: "text",
        },
        text: {
            type: String,
            trim: true,
            required: function () {
                return this.messageType === "text";
            },
        },
        // Voice message fields
        audioUrl: {
            type: String,
            required: function () {
                return this.messageType === "voice";
            },
        },
        audioDuration: {
            type: Number, // Duration in seconds
            default: 0,
        },
        // Image message fields
        imageUrls: {
            type: [String],
            default: [],
        },
        // BlurHash for instant image previews (one per image)
        blurHashes: {
            type: [String],
            default: [],
        },
        createdAt: {
            type: Date,
            default: Date.now,
        },
        readBy: [
            {
                type: String, // String references to PostgreSQL User IDs
            },
        ],
        replyTo: {
            id: { type: String }, // Message ID (likely MongoDB ObjectId if internal, or String)
            text: { type: String },
            senderId: { type: String },
            messageType: { type: String, enum: ["text", "voice", "image"], default: "text" },
        },
    },
    { _id: true }
);

const chatSchema = new mongoose.Schema(
    {
        order: {
            type: String, // String reference to PostgreSQL Order ID
            required: true,
            unique: true
        },
        customer: {
            type: String, // String reference to PostgreSQL User ID
            required: true
        },
        rider: {
            type: String, // String reference to PostgreSQL User ID
            required: true
        },
        messages: [messageSchema],
    },
    {
        timestamps: true,
    }
);


chatSchema.index({ customer: 1 });
chatSchema.index({ rider: 1 });

module.exports = mongoose.model("Chat", chatSchema);
