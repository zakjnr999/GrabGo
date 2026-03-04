const prisma = require("../config/prisma");
const OrderReservation = require("../models/OrderReservation");
const DispatchRetryTask = require("../models/DispatchRetryTask");
const featureFlags = require("../config/feature_flags");

const ORDER_RESERVATION_ENTITY = "order";
const buildOrderReservationQuery = (query = {}) =>
  OrderReservation.buildEntityQuery(ORDER_RESERVATION_ENTITY, query);

const parsePositiveIntEnv = (name, fallback, { min = 1, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const parsed = Number.parseInt(String(process.env[name]), 10);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return fallback;
  }
  return parsed;
};

const CONFIG = {
  baseDelaySeconds: parsePositiveIntEnv("DISPATCH_RETRY_BASE_DELAY_SECONDS", 30, { min: 5, max: 600 }),
  maxDelaySeconds: parsePositiveIntEnv("DISPATCH_RETRY_MAX_DELAY_SECONDS", 300, { min: 15, max: 3600 }),
  maxAttempts: parsePositiveIntEnv("DISPATCH_RETRY_MAX_ATTEMPTS", 120, { min: 1, max: 1000 }),
  processingStaleSeconds: parsePositiveIntEnv("DISPATCH_RETRY_STALE_PROCESSING_SECONDS", 90, {
    min: 15,
    max: 900,
  }),
};

const RECOVERABLE_DISPATCH_ERRORS = new Set([
  "No eligible riders available",
  "Max dispatch attempts reached",
  "Dispatch deferred until vendor is closer to ready",
]);

const TERMINAL_ORDER_STATUSES = new Set(["cancelled", "delivered"]);

const shouldTriggerDispatchForStatus = (status) =>
  status === "preparing" ||
  status === "ready" ||
  (featureFlags.isConfirmedPredispatchEnabled && status === "confirmed");

const shouldTriggerDispatchForOrder = (order, status = order?.status) => {
  if (!order) return false;
  if (order.fulfillmentMode === "pickup") return false;
  if (order.paymentMethod === "cash") {
    return status === "preparing" || status === "ready";
  }
  return shouldTriggerDispatchForStatus(status);
};

const isRecoverableDispatchFailure = (result) => {
  if (!result || result.success) return false;
  if (result.code === "PREDISPATCH_DEFERRED") return true;
  return RECOVERABLE_DISPATCH_ERRORS.has(result.error);
};

const computeBackoffDelaySeconds = (attemptCount = 0, overrideDelaySeconds = null) => {
  if (Number.isFinite(overrideDelaySeconds) && overrideDelaySeconds > 0) {
    return Math.min(CONFIG.maxDelaySeconds, Math.max(5, Math.floor(overrideDelaySeconds)));
  }

  const safeAttempt = Math.max(0, Number(attemptCount) || 0);
  const exponential = Math.floor(CONFIG.baseDelaySeconds * Math.pow(1.5, safeAttempt));
  return Math.min(CONFIG.maxDelaySeconds, Math.max(CONFIG.baseDelaySeconds, exponential));
};

const mergeMetadata = (base = {}, patch = {}) => ({
  ...(base && typeof base === "object" ? base : {}),
  ...(patch && typeof patch === "object" ? patch : {}),
});

const computeDelayUntil = (targetDate, now = new Date()) => {
  if (!(targetDate instanceof Date) || Number.isNaN(targetDate.getTime())) {
    return CONFIG.baseDelaySeconds;
  }
  return Math.max(1, Math.ceil((targetDate.getTime() - now.getTime()) / 1000));
};

const isDuplicateKeyError = (error) =>
  Number(error?.code) === 11000 || String(error?.codeName || "").toLowerCase() === "duplicatekey";

const enqueueDispatchRetry = async ({
  orderId,
  orderNumber = null,
  result = null,
  reason = null,
  source = "unknown",
  delaySeconds = null,
  metadata = {},
}) => {
  if (!orderId) return { enqueued: false, reason: "missing_order_id" };

  const derivedReason = reason || result?.code || result?.error || "dispatch_retry";
  const derivedError = result?.error || null;

  const existing = await DispatchRetryTask.findOne({
    entityType: "order",
    orderId,
    active: true,
  });

  const now = new Date();
  const nextDelaySeconds = computeBackoffDelaySeconds(existing?.attemptCount || 0, delaySeconds);
  const proposedNextRetryAt = new Date(now.getTime() + nextDelaySeconds * 1000);

  if (!existing) {
    let created = null;
    try {
      created = await DispatchRetryTask.create({
        entityType: "order",
        orderId,
        orderNumber,
        active: true,
        state: "pending",
        reason: derivedReason,
        source,
        lastError: derivedError,
        maxAttempts: CONFIG.maxAttempts,
        nextRetryAt: proposedNextRetryAt,
        metadata,
      });
    } catch (error) {
      if (!isDuplicateKeyError(error)) {
        throw error;
      }
      const concurrent = await DispatchRetryTask.findOne({
        entityType: "order",
        orderId,
        active: true,
      });
      if (!concurrent) {
        throw error;
      }
      return {
        enqueued: true,
        created: false,
        taskId: concurrent._id.toString(),
        nextRetryAt: concurrent.nextRetryAt || proposedNextRetryAt,
        delaySeconds: computeDelayUntil(concurrent.nextRetryAt || proposedNextRetryAt, now),
      };
    }

    return {
      enqueued: true,
      created: true,
      taskId: created._id.toString(),
      nextRetryAt: created.nextRetryAt,
      delaySeconds: nextDelaySeconds,
    };
  }

  const existingLockedAt = existing.lockedAt instanceof Date ? existing.lockedAt : null;
  const isFreshProcessingLock =
    existing.state === "processing" &&
    existingLockedAt &&
    now.getTime() - existingLockedAt.getTime() < CONFIG.processingStaleSeconds * 1000;

  if (isFreshProcessingLock) {
    const nextRetryAtWhileProcessing =
      existing.nextRetryAt instanceof Date && existing.nextRetryAt.getTime() > now.getTime()
        ? existing.nextRetryAt
        : proposedNextRetryAt;

    const updatedProcessing = await DispatchRetryTask.findOneAndUpdate(
      { _id: existing._id, active: true, state: "processing" },
      {
        $set: {
          orderNumber: orderNumber || existing.orderNumber || null,
          reason: derivedReason,
          source,
          lastError: derivedError,
          nextRetryAt: nextRetryAtWhileProcessing,
          metadata: mergeMetadata(existing.metadata, metadata),
        },
      },
      { new: true }
    );

    const lockedTask = updatedProcessing || existing;
    return {
      enqueued: true,
      created: false,
      taskId: lockedTask?._id?.toString?.() || null,
      nextRetryAt: lockedTask?.nextRetryAt || nextRetryAtWhileProcessing,
      delaySeconds: computeDelayUntil(lockedTask?.nextRetryAt || nextRetryAtWhileProcessing, now),
    };
  }

  const keepSoonerRetryTime =
    existing.nextRetryAt instanceof Date &&
    existing.nextRetryAt.getTime() > now.getTime() &&
    existing.nextRetryAt.getTime() < proposedNextRetryAt.getTime()
      ? existing.nextRetryAt
      : proposedNextRetryAt;

  const updated = await DispatchRetryTask.findOneAndUpdate(
    { _id: existing._id, active: true },
    {
      $set: {
        orderNumber: orderNumber || existing.orderNumber || null,
        state: "pending",
        reason: derivedReason,
        source,
        lastError: derivedError,
        nextRetryAt: keepSoonerRetryTime,
        lockedAt: null,
        lockedBy: null,
        metadata: mergeMetadata(existing.metadata, metadata),
      },
      $setOnInsert: {
        maxAttempts: CONFIG.maxAttempts,
      },
    },
    { new: true }
  );

  if (!updated) {
    const fallbackExisting = await DispatchRetryTask.findOne({
      entityType: "order",
      orderId,
      active: true,
    });

    if (fallbackExisting) {
      return {
        enqueued: true,
        created: false,
        taskId: fallbackExisting._id.toString(),
        nextRetryAt: fallbackExisting.nextRetryAt || keepSoonerRetryTime,
        delaySeconds: computeDelayUntil(fallbackExisting.nextRetryAt || keepSoonerRetryTime, now),
      };
    }

    let recreated = null;
    try {
      recreated = await DispatchRetryTask.create({
        entityType: "order",
        orderId,
        orderNumber,
        active: true,
        state: "pending",
        reason: derivedReason,
        source,
        lastError: derivedError,
        maxAttempts: CONFIG.maxAttempts,
        nextRetryAt: keepSoonerRetryTime,
        metadata,
      });
    } catch (error) {
      if (!isDuplicateKeyError(error)) {
        throw error;
      }
      const concurrent = await DispatchRetryTask.findOne({
        entityType: "order",
        orderId,
        active: true,
      });
      if (!concurrent) {
        throw error;
      }
      return {
        enqueued: true,
        created: false,
        taskId: concurrent._id.toString(),
        nextRetryAt: concurrent.nextRetryAt || keepSoonerRetryTime,
        delaySeconds: computeDelayUntil(concurrent.nextRetryAt || keepSoonerRetryTime, now),
      };
    }

    return {
      enqueued: true,
      created: true,
      taskId: recreated._id.toString(),
      nextRetryAt: recreated.nextRetryAt,
      delaySeconds: computeDelayUntil(recreated.nextRetryAt, now),
    };
  }

  return {
    enqueued: true,
    created: false,
    taskId: updated?._id?.toString?.() || null,
    nextRetryAt: updated?.nextRetryAt || keepSoonerRetryTime,
    delaySeconds: computeDelayUntil(updated?.nextRetryAt || keepSoonerRetryTime, now),
  };
};

const finalizeDispatchRetry = async (orderId, state, completionReason, lastError = null) => {
  if (!orderId) return null;
  return DispatchRetryTask.findOneAndUpdate(
    { entityType: "order", orderId, active: true },
    {
      $set: {
        active: false,
        state,
        completionReason,
        lastError: lastError || null,
        completedAt: new Date(),
        nextRetryAt: null,
        lockedAt: null,
        lockedBy: null,
      },
    },
    { new: true }
  );
};

const markRetryResolved = async (orderId, completionReason = "dispatch_succeeded") =>
  finalizeDispatchRetry(orderId, "completed", completionReason);

const markRetryCancelled = async (orderId, completionReason = "order_cancelled") =>
  finalizeDispatchRetry(orderId, "cancelled", completionReason);

const markRetryAbandoned = async (orderId, completionReason = "max_retry_attempts", lastError = null) =>
  finalizeDispatchRetry(orderId, "abandoned", completionReason, lastError);

const resetDispatchAttemptHistory = async (orderId) => {
  if (!orderId) return 0;
  const result = await OrderReservation.updateMany(
    buildOrderReservationQuery({ orderId }),
    { $set: { status: "cancelled" } }
  );
  return Number(result?.modifiedCount || result?.nModified || 0);
};

const getDispatchRetryContext = async (orderId) => {
  const order = await prisma.order.findUnique({
    where: { id: orderId },
    select: {
      id: true,
      orderNumber: true,
      status: true,
      paymentStatus: true,
      paymentMethod: true,
      fulfillmentMode: true,
      riderId: true,
    },
  });

  if (!order) {
    return { exists: false, terminal: true, terminalReason: "order_not_found", order: null };
  }

  if (order.riderId) {
    return { exists: true, terminal: true, terminalReason: "rider_assigned", order };
  }

  if (order.fulfillmentMode === "pickup") {
    return { exists: true, terminal: true, terminalReason: "pickup_order", order };
  }

  if (TERMINAL_ORDER_STATUSES.has(order.status)) {
    return { exists: true, terminal: true, terminalReason: `order_${order.status}`, order };
  }

  if (!["paid", "successful"].includes(order.paymentStatus)) {
    return { exists: true, terminal: true, terminalReason: `payment_${order.paymentStatus}`, order };
  }

  if (!shouldTriggerDispatchForOrder(order, order.status)) {
    return { exists: true, terminal: true, terminalReason: `status_${order.status}_not_dispatchable`, order };
  }

  return { exists: true, terminal: false, terminalReason: null, order };
};

module.exports = {
  CONFIG,
  isRecoverableDispatchFailure,
  enqueueDispatchRetry,
  markRetryResolved,
  markRetryCancelled,
  markRetryAbandoned,
  resetDispatchAttemptHistory,
  getDispatchRetryContext,
};
