const cron = require("node-cron");
const prisma = require("../config/prisma");
const cache = require("../utils/cache");
const { sendOrderNotification } = require("../services/fcm_service");
const { createNotification } = require("../services/notification_service");
const { getIO } = require("../utils/socket");
const featureFlags = require("../config/feature_flags");
const { cancelPickupOrder } = require("../services/pickup_order_service");
const { createScopedLogger } = require("../utils/logger");

const console = createScopedLogger("pickup_accept_timeout_job");

const PICKUP_ACCEPT_TIMEOUT_MINUTES = Number(process.env.PICKUP_ACCEPT_TIMEOUT_MINUTES || 10);

const processPickupAcceptTimeouts = async (io = null) => {
  if (!featureFlags.isPickupVendorOpsEnabled) {
    return { processed: 0, cancelled: 0 };
  }

  const now = new Date();
  const expiredOrders = await prisma.order.findMany({
    where: {
      fulfillmentMode: "pickup",
      status: "confirmed",
      acceptByAt: { not: null, lte: now },
      paymentStatus: { in: ["paid", "successful"] },
    },
    select: {
      id: true,
      orderNumber: true,
      customerId: true,
      status: true,
    },
  });

  let cancelled = 0;
  const ioInstance = io || getIO();

  for (const order of expiredOrders) {
    try {
      const updatedOrder = await cancelPickupOrder({
        orderId: order.id,
        reason: `Vendor did not accept within ${PICKUP_ACCEPT_TIMEOUT_MINUTES} minutes`,
        refund: true,
        actorRole: "system",
        action: "pickup_accept_timeout",
        metadata: {
          timeoutMinutes: PICKUP_ACCEPT_TIMEOUT_MINUTES,
          previousStatus: order.status,
        },
      });

      await sendOrderNotification(
        updatedOrder.customerId,
        updatedOrder.id,
        updatedOrder.orderNumber,
        "cancelled",
        "Pickup order was cancelled because the vendor did not accept in time. A refund has been initiated."
      );

      await createNotification(
        updatedOrder.customerId,
        "order",
        `❌ Order #${updatedOrder.orderNumber}`,
        "Pickup order timed out due to vendor non-response. Refund has been initiated.",
        {
          orderId: updatedOrder.id,
          orderNumber: updatedOrder.orderNumber,
          status: "cancelled",
          route: `/orders/${updatedOrder.id}`,
        },
        ioInstance
      );

      cancelled += 1;
    } catch (error) {
      console.error(`❌ Pickup accept-timeout failed for order ${order.id}:`, error.message);
    }
  }

  return { processed: expiredOrders.length, cancelled };
};

const initializePickupAcceptTimeoutJob = (io) => {
  console.log("📅 Initializing pickup accept-timeout job...");

  cron.schedule("* * * * *", async () => {
    const lock = await cache.acquireLock("job:pickup_accept_timeout", 50);
    if (!lock) {
      return;
    }

    try {
      await processPickupAcceptTimeouts(io);
    } catch (error) {
      console.error("Pickup accept-timeout job error:", error.message);
    } finally {
      await cache.releaseLock(lock);
    }
  });

  console.log("✅ Pickup accept-timeout job scheduled (runs every minute)");
};

module.exports = {
  initializePickupAcceptTimeoutJob,
  processPickupAcceptTimeouts,
};
