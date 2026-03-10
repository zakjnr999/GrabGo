const os = require("os");
const cache = require("../utils/cache");
const DispatchRetryTask = require("../models/DispatchRetryTask");
const dispatchService = require("../services/dispatch_service");
const dispatchRetryService = require("../services/dispatch_retry_service");
const { createScopedLogger } = require("../utils/logger");

const console = createScopedLogger("dispatch_retry_queue_job");

const parsePositiveIntEnv = (name, fallback, { min = 1, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const parsed = Number.parseInt(String(process.env[name]), 10);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return fallback;
  }
  return parsed;
};

const CHECK_INTERVAL_MS = parsePositiveIntEnv("DISPATCH_RETRY_JOB_INTERVAL_MS", 10000, { min: 2000, max: 120000 });
const LOCK_TTL_SECONDS = parsePositiveIntEnv("DISPATCH_RETRY_JOB_LOCK_TTL_SECONDS", 8, { min: 3, max: 120 });
const BATCH_LIMIT = parsePositiveIntEnv("DISPATCH_RETRY_JOB_BATCH_LIMIT", 20, { min: 1, max: 200 });
const STALE_PROCESSING_SECONDS = parsePositiveIntEnv("DISPATCH_RETRY_STALE_PROCESSING_SECONDS", 90, {
  min: 15,
  max: 900,
});

const WORKER_ID = `${os.hostname()}-${process.pid}`;

let intervalId = null;
let isRunning = false;
let consecutiveErrors = 0;
const MAX_CONSECUTIVE_ERRORS = 10;

const processTask = async (task) => {
  const now = new Date();
  const claimed = await DispatchRetryTask.findOneAndUpdate(
    {
      _id: task._id,
      active: true,
      state: "pending",
      nextRetryAt: { $ne: null, $lte: now },
    },
    {
      $set: {
        state: "processing",
        lockedAt: new Date(),
        lockedBy: WORKER_ID,
        lastAttemptAt: new Date(),
      },
      $inc: { attemptCount: 1 },
    },
    { new: true }
  );

  if (!claimed) {
    return;
  }

  try {
    if (claimed.attemptCount > claimed.maxAttempts) {
      await dispatchRetryService.markRetryAbandoned(
        claimed.orderId,
        "queue_max_attempts_reached",
        claimed.lastError || "Dispatch retry queue max attempts reached"
      );
      console.log(
        `🛑 [DispatchRetryQueue] Max attempts reached for order ${claimed.orderNumber || claimed.orderId} (attempts=${claimed.attemptCount})`
      );
      return;
    }

    const context = await dispatchRetryService.getDispatchRetryContext(claimed.orderId);
    if (context.terminal) {
      const reason = context.terminalReason || "terminal";
      if (reason === "rider_assigned") {
        await dispatchRetryService.markRetryResolved(claimed.orderId, reason);
      } else {
        await dispatchRetryService.markRetryCancelled(claimed.orderId, reason);
      }
      console.log(`✅ [DispatchRetryQueue] Closed task for order ${claimed.orderId}: ${reason}`);
      return;
    }

    const dispatchResult = await dispatchService.dispatchOrder(claimed.orderId);
    if (dispatchResult.success) {
      await dispatchRetryService.markRetryResolved(claimed.orderId, "dispatch_succeeded");
      console.log(
        `✅ [DispatchRetryQueue] Dispatch succeeded for order ${context.order.orderNumber} -> rider ${dispatchResult.riderName}`
      );
      return;
    }

    if (!dispatchRetryService.isRecoverableDispatchFailure(dispatchResult)) {
      await dispatchRetryService.markRetryAbandoned(
        claimed.orderId,
        "non_recoverable_dispatch_error",
        dispatchResult.error || null
      );
      console.log(
        `🛑 [DispatchRetryQueue] Abandoning order ${context.order.orderNumber}: ${dispatchResult.error}`
      );
      return;
    }

    if (dispatchResult.error === "Max dispatch attempts reached") {
      const resetCount = await dispatchRetryService.resetDispatchAttemptHistory(claimed.orderId);
      console.log(
        `🧹 [DispatchRetryQueue] Reset ${resetCount} reservation attempts for ${context.order.orderNumber}`
      );
    }

    const enqueueResult = await dispatchRetryService.enqueueDispatchRetry({
      orderId: claimed.orderId,
      orderNumber: context.order.orderNumber,
      result: dispatchResult,
      source: "dispatch_retry_queue",
      metadata: {
        queueAttemptCount: claimed.attemptCount,
      },
    });

    const nowMs = Date.now();
    const proposedRetryAt =
      enqueueResult?.nextRetryAt instanceof Date ? enqueueResult.nextRetryAt.getTime() : null;
    const nextRetryAtMs =
      Number.isFinite(proposedRetryAt) && proposedRetryAt > nowMs + 1000
        ? proposedRetryAt
        : nowMs + 30000;
    const nextRetryAt = new Date(nextRetryAtMs);
    const effectiveDelaySeconds = Math.max(1, Math.ceil((nextRetryAtMs - nowMs) / 1000));

    await DispatchRetryTask.findOneAndUpdate(
      { _id: claimed._id, active: true },
      {
        $set: {
          state: "pending",
          nextRetryAt,
          lockedAt: null,
          lockedBy: null,
          lastError: dispatchResult.error || null,
        },
      }
    );

    console.log(
      `🔄 [DispatchRetryQueue] Re-queued ${context.order.orderNumber} after failure: ${dispatchResult.error} (next in ${effectiveDelaySeconds}s)`
    );
  } catch (error) {
    let fallbackNextRetryAt = new Date(Date.now() + 30000);
    try {
      const enqueueResult = await dispatchRetryService.enqueueDispatchRetry({
        orderId: claimed.orderId,
        orderNumber: claimed.orderNumber,
        reason: "queue_processing_error",
        source: "dispatch_retry_queue",
        metadata: {
          queueAttemptCount: claimed.attemptCount,
        },
        delaySeconds: 30,
      });
      if (enqueueResult?.nextRetryAt instanceof Date) {
        fallbackNextRetryAt = enqueueResult.nextRetryAt;
      }
    } catch (enqueueError) {
      console.error(
        `❌ [DispatchRetryQueue] Failed to enqueue recovery retry for order ${claimed.orderId}:`,
        enqueueError.message
      );
    }

    await DispatchRetryTask.findOneAndUpdate(
      { _id: claimed._id, active: true },
      {
        $set: {
          state: "pending",
          lastError: error.message,
          lockedAt: null,
          lockedBy: null,
          nextRetryAt: fallbackNextRetryAt,
        },
      }
    );
    console.error(
      `❌ [DispatchRetryQueue] Task error for order ${claimed.orderId}:`,
      error.message
    );
  }
};

const processDueDispatchRetries = async () => {
  const lock = await cache.acquireLock("job:dispatch_retry_queue", LOCK_TTL_SECONDS);
  if (!lock) return;
  if (isRunning) {
    await cache.releaseLock(lock);
    return;
  }

  isRunning = true;
  try {
    const staleThreshold = new Date(Date.now() - STALE_PROCESSING_SECONDS * 1000);
    const staleReset = await DispatchRetryTask.updateMany(
      {
        entityType: "order",
        active: true,
        state: "processing",
        lockedAt: { $lte: staleThreshold },
      },
      {
        $set: {
          state: "pending",
          nextRetryAt: new Date(),
          lockedAt: null,
          lockedBy: null,
          lastError: "Recovered stale processing lock",
        },
      }
    );
    if ((staleReset.modifiedCount || 0) > 0) {
      console.log(`🧹 [DispatchRetryQueue] Reset ${staleReset.modifiedCount} stale processing task(s)`);
    }

    const dueTasks = await DispatchRetryTask.findDue(BATCH_LIMIT, new Date());
    if (dueTasks.length === 0) {
      consecutiveErrors = 0;
      return;
    }

    console.log(`\n🔄 [DispatchRetryQueue] Processing ${dueTasks.length} due retry task(s)`);
    for (const task of dueTasks) {
      // Process sequentially to avoid dispatching the same order family in parallel.
      await processTask(task);
    }
    consecutiveErrors = 0;
  } catch (error) {
    consecutiveErrors += 1;
    console.error(
      `❌ [DispatchRetryQueue] Job error (${consecutiveErrors}/${MAX_CONSECUTIVE_ERRORS}):`,
      error.message
    );

    if (consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
      console.error("❌ [DispatchRetryQueue] Too many consecutive errors, pausing worker...");
      stop();
      setTimeout(() => {
        consecutiveErrors = 0;
        start();
      }, 30000);
    }
  } finally {
    isRunning = false;
    await cache.releaseLock(lock);
  }
};

const start = () => {
  if (intervalId) {
    console.log("[DispatchRetryQueue] Worker already running");
    return;
  }

  console.log(`✅ [DispatchRetryQueue] Starting worker (every ${CHECK_INTERVAL_MS / 1000}s)`);
  intervalId = setInterval(processDueDispatchRetries, CHECK_INTERVAL_MS);
  processDueDispatchRetries().catch((error) => {
    console.error("[DispatchRetryQueue] Initial run failed:", error.message);
  });
};

const stop = () => {
  if (!intervalId) return;
  clearInterval(intervalId);
  intervalId = null;
  console.log("🛑 [DispatchRetryQueue] Worker stopped");
};

const getStatus = () => ({
  running: Boolean(intervalId),
  processing: isRunning,
  checkIntervalMs: CHECK_INTERVAL_MS,
  lockTtlSeconds: LOCK_TTL_SECONDS,
  batchLimit: BATCH_LIMIT,
  staleProcessingSeconds: STALE_PROCESSING_SECONDS,
  workerId: WORKER_ID,
  consecutiveErrors,
});

module.exports = {
  start,
  stop,
  getStatus,
  processDueDispatchRetries,
};
