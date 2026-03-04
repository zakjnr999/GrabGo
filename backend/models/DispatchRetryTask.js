const mongoose = require("mongoose");

const dispatchRetryTaskSchema = new mongoose.Schema(
  {
    entityType: {
      type: String,
      enum: ["order"],
      default: "order",
      index: true,
    },
    orderId: {
      type: String,
      required: true,
      index: true,
    },
    orderNumber: {
      type: String,
      default: null,
    },
    active: {
      type: Boolean,
      default: true,
      index: true,
    },
    state: {
      type: String,
      enum: ["pending", "processing", "completed", "cancelled", "abandoned"],
      default: "pending",
      index: true,
    },
    reason: {
      type: String,
      default: null,
    },
    source: {
      type: String,
      default: null,
    },
    lastError: {
      type: String,
      default: null,
    },
    attemptCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    maxAttempts: {
      type: Number,
      default: 120,
      min: 1,
    },
    nextRetryAt: {
      type: Date,
      default: null,
      index: true,
    },
    lastAttemptAt: {
      type: Date,
      default: null,
    },
    lockedAt: {
      type: Date,
      default: null,
    },
    lockedBy: {
      type: String,
      default: null,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    completedAt: {
      type: Date,
      default: null,
    },
    completionReason: {
      type: String,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

dispatchRetryTaskSchema.index(
  { entityType: 1, orderId: 1, active: 1 },
  { unique: true, partialFilterExpression: { active: true } }
);
dispatchRetryTaskSchema.index({ active: 1, state: 1, nextRetryAt: 1 });

dispatchRetryTaskSchema.statics.findDue = async function(limit = 20, now = new Date()) {
  return this.find({
    entityType: "order",
    active: true,
    state: "pending",
    nextRetryAt: { $ne: null, $lte: now },
  })
    .sort({ nextRetryAt: 1, createdAt: 1 })
    .limit(limit);
};

module.exports = mongoose.model("DispatchRetryTask", dispatchRetryTaskSchema);
