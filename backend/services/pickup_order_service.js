const prisma = require("../config/prisma");

const STOCK_MODELS = {
  GroceryItem: prisma.groceryItem,
  PharmacyItem: prisma.pharmacyItem,
  GrabMartItem: prisma.grabMartItem,
};

const canRefundPaymentStatus = (paymentStatus) => ["paid", "successful"].includes(paymentStatus);

const normalizePromoCode = (value) => {
  if (!value) return null;
  const normalized = String(value).trim().toUpperCase();
  return normalized.length > 0 ? normalized : null;
};

const decrementPromoUsageIfNeeded = async ({ tx = prisma, promoCode }) => {
  const normalizedCode = normalizePromoCode(promoCode);
  if (!normalizedCode) return;

  await tx.promoCode.updateMany({
    where: {
      code: normalizedCode,
      currentUses: { gt: 0 },
    },
    data: {
      currentUses: { decrement: 1 },
    },
  }).catch(() => null);
};

const createOrderAudit = async ({
  tx = prisma,
  orderId,
  actorId = null,
  actorRole = "system",
  action,
  reason = null,
  metadata = null,
}) => {
  return tx.orderActionAudit.create({
    data: {
      orderId,
      actorId,
      actorRole,
      action,
      reason,
      metadata,
    },
  });
};

const reserveInventoryForOrder = async ({ orderId, tx = prisma }) => {
  const order = await tx.order.findUnique({
    where: { id: orderId },
    include: {
      items: true,
      inventoryHolds: {
        where: { releasedAt: null },
      },
    },
  });

  if (!order) {
    throw new Error("Order not found");
  }

  if (!["pending", "confirmed", "preparing", "ready"].includes(order.status)) {
    return [];
  }

  if (order.inventoryHolds.length > 0) {
    return order.inventoryHolds;
  }

  const createdHolds = [];

  for (const item of order.items) {
    if (!["GroceryItem", "PharmacyItem", "GrabMartItem"].includes(item.itemType)) {
      continue;
    }

    const model = STOCK_MODELS[item.itemType];
    const sourceItemId =
      item.itemType === "GroceryItem"
        ? item.groceryItemId
        : item.itemType === "PharmacyItem"
          ? item.pharmacyItemId
          : item.grabMartItemId;

    if (!sourceItemId) {
      throw new Error(`Missing source item for ${item.itemType} in order ${orderId}`);
    }

    const updated = await model.updateMany({
      where: {
        id: sourceItemId,
        stock: { gte: item.quantity },
      },
      data: {
        stock: { decrement: item.quantity },
      },
    });

    if (updated.count === 0) {
      throw new Error(`Insufficient stock for item ${item.name}`);
    }

    const hold = await tx.orderInventoryHold.create({
      data: {
        orderId: order.id,
        orderItemId: item.id,
        itemType: item.itemType,
        itemId: sourceItemId,
        reservedQty: item.quantity,
      },
    });
    createdHolds.push(hold);
  }

  return createdHolds;
};

const releaseInventoryHolds = async ({ orderId, tx = prisma }) => {
  const activeHolds = await tx.orderInventoryHold.findMany({
    where: {
      orderId,
      releasedAt: null,
    },
  });

  if (activeHolds.length === 0) {
    return { releasedCount: 0 };
  }

  for (const hold of activeHolds) {
    if (!["GroceryItem", "PharmacyItem", "GrabMartItem"].includes(hold.itemType)) {
      continue;
    }

    const model = STOCK_MODELS[hold.itemType];
    await model.update({
      where: { id: hold.itemId },
      data: {
        stock: { increment: hold.reservedQty },
      },
    });
  }

  const now = new Date();
  await tx.orderInventoryHold.updateMany({
    where: {
      orderId,
      releasedAt: null,
    },
    data: {
      releasedAt: now,
      updatedAt: now,
    },
  });

  return { releasedCount: activeHolds.length };
};

const cancelPickupOrder = async ({
  orderId,
  reason,
  refund = true,
  actorId = null,
  actorRole = "system",
  action = "pickup_cancelled",
  metadata = null,
}) => {
  return prisma.$transaction(async (tx) => {
    const order = await tx.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        orderNumber: true,
        status: true,
        fulfillmentMode: true,
        paymentStatus: true,
        promoCode: true,
      },
    });

    if (!order) {
      throw new Error("Order not found");
    }

    if (order.fulfillmentMode !== "pickup") {
      throw new Error("Order is not a pickup order");
    }

    if (order.status === "cancelled") {
      return order;
    }

    const nextPaymentStatus = refund && canRefundPaymentStatus(order.paymentStatus)
      ? "refunded"
      : order.paymentStatus;

    const updatedOrder = await tx.order.update({
      where: { id: orderId },
      data: {
        status: "cancelled",
        cancelledDate: new Date(),
        cancellationReason: reason,
        paymentStatus: nextPaymentStatus,
        updatedAt: new Date(),
      },
    });

    await decrementPromoUsageIfNeeded({ tx, promoCode: order.promoCode });

    await releaseInventoryHolds({ orderId, tx });

    await createOrderAudit({
      tx,
      orderId,
      actorId,
      actorRole,
      action,
      reason,
      metadata,
    });

    return updatedOrder;
  });
};

module.exports = {
  canRefundPaymentStatus,
  createOrderAudit,
  reserveInventoryForOrder,
  releaseInventoryHolds,
  cancelPickupOrder,
};
