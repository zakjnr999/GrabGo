const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
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
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    replyTo: {
      id: { type: mongoose.Schema.Types.ObjectId },
      text: { type: String },
      senderId: { type: mongoose.Schema.Types.ObjectId },
      messageType: { type: String, enum: ["text", "voice", "image"], default: "text" },
    },
  },
  { _id: true }
);

const chatSchema = new mongoose.Schema(
  {
    order: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Order",
      required: true,
    },
    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    rider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    messages: [messageSchema],
  },
  {
    timestamps: true,
  }
);

chatSchema.index({ order: 1 }, { unique: true });
chatSchema.index({ customer: 1 });
chatSchema.index({ rider: 1 });

module.exports = mongoose.model("Chat", chatSchema);
