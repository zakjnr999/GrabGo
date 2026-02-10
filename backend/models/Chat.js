const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
    {
        sender: {
            type: String,
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
        audioUrl: {
            type: String,
            required: function () {
                return this.messageType === "voice";
            },
        },
        audioDuration: {
            type: Number,
            default: 0,
        },
        imageUrls: {
            type: [String],
            default: [],
        },
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
                type: String,
            },
        ],
        replyTo: {
            id: { type: String },
            text: { type: String },
            senderId: { type: String },
            messageType: { type: String, enum: ["text", "voice", "image"], default: "text" },
        },
    },
    { _id: true }
);

const chatSchema = new mongoose.Schema(
    {
        orderId: {
            type: String,
            required: true,
            unique: true
        },
        customerId: {
            type: String,
            required: true
        },
        riderId: {
            type: String,
            required: true
        },
    },
    {
        timestamps: true,
    }
);

chatSchema.index({ customerId: 1 });
chatSchema.index({ riderId: 1 });
chatSchema.index({ orderId: 1 });

module.exports = mongoose.model("Chat", chatSchema);
