const mongoose = require("mongoose");

const callLogSchema = new mongoose.Schema(
  {
    order: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Order",
      required: true,
    },
    caller: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    callType: {
      type: String,
      enum: ["direct", "masked", "webrtc"],
      default: "webrtc",
    },
    status: {
      type: String,
      enum: [
        "initiated",
        "ringing",
        "active",
        "completed",
        "missed",
        "rejected",
        "failed",
      ],
      default: "initiated",
    },
    duration: {
      type: Number,
      default: 0,
    },
    isVideoCall: {
      type: Boolean,
      default: false,
    },
    startedAt: {
      type: Date,
      default: Date.now,
    },
    endedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

callLogSchema.index({ order: 1 });
callLogSchema.index({ caller: 1 });
callLogSchema.index({ recipient: 1 });
callLogSchema.index({ createdAt: -1 });

module.exports = mongoose.model("CallLog", callLogSchema);