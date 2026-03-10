const cron = require("node-cron");
const prisma = require("../config/prisma");
const cache = require("../utils/cache");
const { sendOrderNotification } = require("../services/fcm_service");
const { createNotification } = require("../services/notification_service");
const { getIO } = require("../utils/socket");
const featureFlags = require("../config/feature_flags");
const { cancelPickupOrder } = require("../services/pickup_order_service");
const { createScopedLogger } = require("../utils/logger");

const console = createScopedLogger("pickup_ready_expiry_job");

const PICKUP_READY_EXPIRY_MINUTES = Number(process.env.PICKUP_READY_EXPIRY_MINUTES || 30);

const processPickupReadyExpiries = async (io = null) => {
  if (!featureFlags.isPickupReadyExpiryEnabled) {
    return { processed: 0, expired: 0 };
  }

  const now = new Date();
  const expiredOrders = await prisma.order.findMany({
    where: {
      fulfillmentMode: "pickup",
      status: "ready",
      pickupExpiresAt: { not: null, lte: now },
    },
    select: {
      id: true,
      orderNumber: true,
      customerId: true,
      status: true,
      paymentStatus: true,
    },
  });

  let expired = 0;
  const ioInstance = io || getIO();

  for (const order of expiredOrders) {
    try {
      const updatedOrder = await cancelPickupOrder({
        orderId: order.id,
        reason: `Customer did not pick up within ${PICKUP_READY_EXPIRY_MINUTES} minutes`,
        refund: false,
        actorRole: "system",
        action: "pickup_no_show_expired",
        metadata: {
          expiryMinutes: PICKUP_READY_EXPIRY_MINUTES,
          previousStatus: order.status,
        },
      });

      await sendOrderNotification(
        updatedOrder.customerId,
        updatedOrder.id,
        updatedOrder.orderNumber,
        "cancelled",
        "Pickup order expired due to no-show. Please place a new order when ready."
      );

      await createNotification(
        updatedOrder.customerId,
        "order",
        `⌛ Order #${updatedOrder.orderNumber}`,
        "Pickup window expired because the order was not collected in time.",
        {
          orderId: updatedOrder.id,
          orderNumber: updatedOrder.orderNumber,
          status: "cancelled",
          route: `/orders/${updatedOrder.id}`,
        },
        ioInstance
      );

      expired += 1;
    } catch (error) {
      console.error(`❌ Pickup ready-expiry failed for order ${order.id}:`, error.message);
    }
  }

  return { processed: expiredOrders.length, expired };
};

const initializePickupReadyExpiryJob = (io) => {
  console.log("📅 Initializing pickup ready-expiry job...");

  cron.schedule("* * * * *", async () => {
    const lock = await cache.acquireLock("job:pickup_ready_expiry", 50);
    if (!lock) {
      return;
    }

    try {
      await processPickupReadyExpiries(io);
    } catch (error) {
      console.error("Pickup ready-expiry job error:", error.message);
    } finally {
      await cache.releaseLock(lock);
    }
  });

  console.log("✅ Pickup ready-expiry job scheduled (runs every minute)");
};

module.exports = {
  initializePickupReadyExpiryJob,
  processPickupReadyExpiries,
};
