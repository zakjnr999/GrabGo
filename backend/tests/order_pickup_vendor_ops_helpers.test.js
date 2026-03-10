const {
  PickupVendorOpError,
  createOrderPickupVendorOpsHelpers,
} = require("../routes/support/order_pickup_vendor_ops_helpers");

describe("order_pickup_vendor_ops_helpers", () => {
  let prisma;
  let deps;
  let helpers;

  beforeEach(() => {
    prisma = {
      order: {
        update: jest.fn(),
      },
      orderActionAudit: {
        create: jest.fn(),
      },
    };
    deps = {
      hashPickupCode: jest.fn((orderId, code) => `${orderId}:${code}`),
      isPickupOtpLocked: jest.fn(() => false),
      notifyOrderStatusChange: jest.fn(),
    };
    helpers = createOrderPickupVendorOpsHelpers({
      prisma,
      ...deps,
      PICKUP_OTP_MAX_ATTEMPTS: 3,
    });
  });

  it("blocks vendor access when restaurant user does not own the pickup order", () => {
    expect(() =>
      helpers.ensureVendorCanManagePickupOrder({
        order: {
          id: "order-1",
          fulfillmentMode: "pickup",
          restaurantId: "rest-1",
        },
        userRole: "restaurant",
        vendorContext: { restaurantId: "rest-2" },
      })
    ).toThrow(PickupVendorOpError);
  });

  it("accepts a pickup order and notifies the customer", async () => {
    prisma.order.update.mockResolvedValue({ id: "order-2", status: "preparing" });
    prisma.orderActionAudit.create.mockResolvedValue(undefined);

    const result = await helpers.acceptPickupOrderAndNotify({
      orderId: "order-2",
      order: { status: "confirmed", acceptedAt: null },
      actorId: "vendor-1",
      actorRole: "restaurant",
      sanitizeOrderPayload: (value) => ({ ...value, sanitized: true }),
    });

    expect(prisma.order.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "order-2" },
        data: expect.objectContaining({
          status: "preparing",
          rejectReason: null,
          rejectedAt: null,
        }),
      })
    );
    expect(prisma.orderActionAudit.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "pickup_accept",
        metadata: expect.objectContaining({
          previousStatus: "confirmed",
          nextStatus: "preparing",
        }),
      }),
    });
    expect(deps.notifyOrderStatusChange).toHaveBeenCalledWith(
      { id: "order-2", status: "preparing" },
      "preparing",
      "Your pickup order has been accepted and is being prepared."
    );
    expect(result).toEqual({ id: "order-2", status: "preparing", sanitized: true });
  });

  it("rejects pickup code verification when the code is invalid and tracks failed attempts", async () => {
    prisma.order.update.mockResolvedValue(undefined);
    prisma.orderActionAudit.create.mockResolvedValue(undefined);

    await expect(
      helpers.verifyPickupCodeAndCompleteOrder({
        orderId: "order-3",
        order: {
          id: "order-3",
          readyAt: new Date(),
          pickupOtpHash: "order-3:correct",
          pickupOtpFailedAttempts: 2,
        },
        code: "wrong",
        actorId: "vendor-1",
        actorRole: "restaurant",
        sanitizeOrderPayload: (value) => value,
      })
    ).rejects.toMatchObject({ code: "PICKUP_OTP_LOCKED" });

    expect(prisma.order.update).toHaveBeenCalledWith({
      where: { id: "order-3" },
      data: {
        pickupOtpFailedAttempts: 3,
        pickupOtpLastAttemptAt: expect.any(Date),
      },
    });
    expect(prisma.orderActionAudit.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "pickup_otp_failed",
        metadata: { failedAttempts: 3 },
      }),
    });
  });

  it("verifies pickup code, completes the order, and notifies the customer", async () => {
    prisma.order.update.mockResolvedValue({ id: "order-4", status: "picked_up" });
    prisma.orderActionAudit.create.mockResolvedValue(undefined);

    const result = await helpers.verifyPickupCodeAndCompleteOrder({
      orderId: "order-4",
      order: {
        id: "order-4",
        readyAt: new Date(Date.now() - 60000),
        pickupOtpHash: "order-4:123456",
        pickupOtpFailedAttempts: 0,
      },
      code: "123456",
      actorId: "vendor-1",
      actorRole: "restaurant",
      sanitizeOrderPayload: (value) => ({ ...value, sanitized: true }),
    });

    expect(prisma.order.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "order-4" },
        data: expect.objectContaining({
          status: "picked_up",
          pickupOtpFailedAttempts: 0,
          pickupOtpLastAttemptAt: null,
        }),
      })
    );
    expect(prisma.orderActionAudit.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "pickup_verified",
      }),
    });
    expect(deps.notifyOrderStatusChange).toHaveBeenCalledWith(
      { id: "order-4", status: "picked_up" },
      "picked_up",
      "Order pickup verified successfully."
    );
    expect(result).toEqual({ id: "order-4", status: "picked_up", sanitized: true });
  });
});
