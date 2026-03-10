const {
  SupportOrderOpError,
  createOrderSupportOpsHelpers,
} = require("../routes/support/order_support_ops_helpers");

describe("order_support_ops_helpers", () => {
  let prisma;
  let deps;
  let helpers;

  beforeEach(() => {
    prisma = {
      order: {
        update: jest.fn(),
      },
      $transaction: jest.fn(async (cb) =>
        cb({
          order: {
            findUnique: jest.fn().mockResolvedValue({
              status: "confirmed",
              paymentStatus: "paid",
              promoCode: "PROMO10",
            }),
            update: jest.fn().mockResolvedValue({ id: "order-1", status: "cancelled" }),
          },
        })
      ),
    };
    deps = {
      cancelPickupOrder: jest.fn(),
      decrementPromoUsageIfNeeded: jest.fn().mockResolvedValue(undefined),
      createOrderAudit: jest.fn().mockResolvedValue(undefined),
      releaseInventoryHolds: jest.fn().mockResolvedValue(undefined),
      sanitizeOrderPayload: jest.fn((value) => ({ ...value, sanitized: true })),
    };
    helpers = createOrderSupportOpsHelpers({ prisma, ...deps });
  });

  it("throws a typed not-found error when support order is missing", async () => {
    await expect(
      helpers.cancelOrderBySupport({
        orderId: "missing",
        order: null,
        reason: "cancel",
        refund: true,
        actorId: "admin-1",
        actorRole: "admin",
      })
    ).rejects.toBeInstanceOf(SupportOrderOpError);
  });

  it("delegates pickup cancellations to cancelPickupOrder", async () => {
    deps.cancelPickupOrder.mockResolvedValue({ id: "order-p", status: "cancelled" });

    const result = await helpers.cancelOrderBySupport({
      orderId: "order-p",
      order: { id: "order-p", status: "ready", fulfillmentMode: "pickup" },
      reason: "store issue",
      refund: true,
      actorId: "admin-1",
      actorRole: "admin",
    });

    expect(deps.cancelPickupOrder).toHaveBeenCalledWith({
      orderId: "order-p",
      reason: "store issue",
      refund: true,
      actorId: "admin-1",
      actorRole: "admin",
      action: "support_cancel",
      metadata: { previousStatus: "ready" },
    });
    expect(result).toEqual({ id: "order-p", status: "cancelled", sanitized: true });
  });

  it("refunds pickup orders and releases inventory holds", async () => {
    prisma.order.update.mockResolvedValue({ id: "order-r", paymentStatus: "refunded" });

    const result = await helpers.refundOrderBySupport({
      orderId: "order-r",
      order: {
        id: "order-r",
        status: "confirmed",
        paymentStatus: "paid",
        fulfillmentMode: "pickup",
      },
      reason: "manual refund",
      actorId: "admin-1",
      actorRole: "admin",
    });

    expect(prisma.order.update).toHaveBeenCalledWith({
      where: { id: "order-r" },
      data: { paymentStatus: "refunded", updatedAt: expect.any(Date) },
    });
    expect(deps.releaseInventoryHolds).toHaveBeenCalledWith({ orderId: "order-r" });
    expect(deps.createOrderAudit).toHaveBeenCalledWith({
      orderId: "order-r",
      actorId: "admin-1",
      actorRole: "admin",
      action: "support_refund",
      reason: "manual refund",
      metadata: {
        previousPaymentStatus: "paid",
        currentStatus: "confirmed",
      },
    });
    expect(result).toEqual({ id: "order-r", paymentStatus: "refunded", sanitized: true });
  });

  it("force completes pickup orders with pickup timing metadata", async () => {
    prisma.order.update.mockResolvedValue({ id: "order-f", status: "picked_up" });

    const result = await helpers.forceCompleteOrderBySupport({
      orderId: "order-f",
      order: {
        id: "order-f",
        status: "ready",
        fulfillmentMode: "pickup",
        readyAt: new Date(Date.now() - 45000),
      },
      reason: "manual close",
      actorId: "admin-1",
      actorRole: "admin",
    });

    expect(prisma.order.update).toHaveBeenCalledWith({
      where: { id: "order-f" },
      data: expect.objectContaining({
        status: "picked_up",
        pickedUpAt: expect.any(Date),
        pickupReadyToCollectedSeconds: expect.any(Number),
      }),
    });
    expect(deps.createOrderAudit).toHaveBeenCalledWith({
      orderId: "order-f",
      actorId: "admin-1",
      actorRole: "admin",
      action: "support_force_complete",
      reason: "manual close",
      metadata: {
        previousStatus: "ready",
        nextStatus: "picked_up",
      },
    });
    expect(result).toEqual({ id: "order-f", status: "picked_up", sanitized: true });
  });
});
