const cron = require("node-cron");
const prisma = require("../config/prisma");
const cache = require("../utils/cache");
const { sendOrderNotification } = require("../services/fcm_service");
const { createNotification } = require("../services/notification_service");
const { getIO } = require("../utils/socket");
const featureFlags = require("../config/feature_flags");
const { createOrderAudit } = require("../services/pickup_order_service");
const { createScopedLogger } = require("../utils/logger");

const console = createScopedLogger("scheduled_order_release_job");

const parsePositiveIntEnv = (name, fallback, { min = 1, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const parsed = Number.parseInt(String(process.env[name]), 10);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return fallback;
  }
  return parsed;
};

const SCHEDULED_ORDER_RELEASE_LOCK_TTL_SECONDS = parsePositiveIntEnv(
  "SCHEDULED_ORDER_RELEASE_LOCK_TTL_SECONDS",
  110,
  { min: 15, max: 15 * 60 }
);

const processScheduledOrderReleases = async (io = null) => {
  if (!featureFlags.isScheduledOrdersEnabled) {
    return { processed: 0, released: 0 };
  }

  const now = new Date();
  const dueOrders = await prisma.order.findMany({
    where: {
      isScheduledOrder: true,
      fulfillmentMode: "delivery",
      status: "pending",
      paymentStatus: { in: ["paid", "successful"] },
      scheduledReleaseAt: { not: null, lte: now },
      scheduledReleasedAt: null,
    },
    select: {
      id: true,
      orderNumber: true,
      customerId: true,
      scheduledForAt: true,
      scheduledReleaseAt: true,
    },
  });

  let released = 0;
  const ioInstance = io || getIO();

  for (const order of dueOrders) {
    try {
      const releasedAt = new Date();
      const updatedOrder = await prisma.$transaction(async (tx) => {
        const fresh = await tx.order.findUnique({
          where: { id: order.id },
          select: {
            id: true,
            customerId: true,
            orderNumber: true,
            status: true,
            paymentStatus: true,
            scheduledReleasedAt: true,
          },
        });

        if (!fresh) return null;

        if (
          fresh.scheduledReleasedAt ||
          fresh.status !== "pending" ||
          !["paid", "successful"].includes(fresh.paymentStatus)
        ) {
          return null;
        }

        const updated = await tx.order.update({
          where: { id: order.id },
          data: {
            status: "confirmed",
            scheduledReleasedAt: releasedAt,
            updatedAt: releasedAt,
          },
          include: {
            customer: { select: { username: true, email: true, phone: true } },
            restaurant: {
              select: { restaurantName: true, logo: true, address: true, city: true, area: true, latitude: true, longitude: true },
            },
            groceryStore: {
              select: { storeName: true, logo: true, address: true, city: true, area: true, latitude: true, longitude: true },
            },
            pharmacyStore: {
              select: { storeName: true, logo: true, address: true, city: true, area: true, latitude: true, longitude: true },
            },
            grabMartStore: {
              select: { storeName: true, logo: true, address: true, city: true, area: true, latitude: true, longitude: true },
            },
            rider: { select: { username: true, email: true, phone: true } },
          },
        });

        await tx.orderActionAudit.create({
          data: {
            orderId: order.id,
            actorRole: "system",
            action: "scheduled_order_released",
            metadata: {
              scheduledForAt: order.scheduledForAt ? order.scheduledForAt.toISOString() : null,
              scheduledReleaseAt: order.scheduledReleaseAt ? order.scheduledReleaseAt.toISOString() : null,
              releasedAt: releasedAt.toISOString(),
              previousStatus: "pending",
              nextStatus: "confirmed",
            },
          },
        });

        return updated;
      });

      if (!updatedOrder) {
        continue;
      }

      released += 1;

      try {
        await sendOrderNotification(
          updatedOrder.customerId,
          updatedOrder.id,
          updatedOrder.orderNumber,
          "confirmed",
          "Your scheduled order is now being processed."
        );

        await createNotification(
          updatedOrder.customerId,
          "order",
          `✅ Order #${updatedOrder.orderNumber}`,
          "Your scheduled order is now being processed.",
          {
            orderId: updatedOrder.id,
            orderNumber: updatedOrder.orderNumber,
            status: "confirmed",
            route: `/orders/${updatedOrder.id}`,
          },
          ioInstance
        );
      } catch (notificationError) {
        console.error(
          `Scheduled order ${order.orderNumber} released, but customer notification failed:`,
          notificationError.message
        );
      }

      await createOrderAudit({
        orderId: order.id,
        actorRole: "system",
        action: "status_confirmed",
        metadata: {
          previousStatus: "pending",
          nextStatus: "confirmed",
          trigger: "scheduled_order_release_job",
        },
      }).catch(() => null);

      console.log(`📌 Scheduled order ${order.orderNumber} released; awaiting vendor to move to preparing/ready.`);
    } catch (error) {
      console.error(`❌ Scheduled order release failed for order ${order.id}:`, error.message);
    }
  }

  return { processed: dueOrders.length, released };
};

const initializeScheduledOrderReleaseJob = (io) => {
  console.log("📅 Initializing scheduled-order release job...");

  cron.schedule("* * * * *", async () => {
    const lock = await cache.acquireLock("job:scheduled_order_release", SCHEDULED_ORDER_RELEASE_LOCK_TTL_SECONDS);
    if (!lock) {
      return;
    }

    try {
      await processScheduledOrderReleases(io);
    } catch (error) {
      console.error("Scheduled-order release job error:", error.message);
    } finally {
      await cache.releaseLock(lock);
    }
  });

  console.log("✅ Scheduled-order release job scheduled (runs every minute)");
};

module.exports = {
  initializeScheduledOrderReleaseJob,
  processScheduledOrderReleases,
};
