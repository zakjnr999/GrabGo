const {
  DeliveryCodeResendRouteError,
  createOrderDeliveryCodeResendHelpers,
} = require("../routes/support/order_delivery_code_resend_helpers");

describe("order_delivery_code_resend_helpers", () => {
  let prisma;
  let deps;
  let helpers;

  beforeEach(() => {
    prisma = {
      user: {
        findUnique: jest.fn(),
      },
      order: {
        update: jest.fn(),
      },
    };
    deps = {
      DELIVERY_ACTIVE_STATUSES: new Set(["confirmed", "preparing", "on_the_way"]),
      getResendAvailability: jest.fn(() => ({ allowed: true })),
      decryptDeliveryCode: jest.fn(() => "123456"),
      sendDeliveryCodeSms: jest.fn(),
      createOrderAudit: jest.fn(() => Promise.resolve()),
    };
    helpers = createOrderDeliveryCodeResendHelpers({ prisma, ...deps });
  });

  it("rejects rider resend to customer and preserves business code on throttle failure", () => {
    expect(() =>
      helpers.ensureDeliveryCodeResendAllowed({
        order: {
          id: "order-1",
          isGiftOrder: true,
          deliveryVerificationRequired: true,
          deliveryCodeEncrypted: "cipher",
          status: "on_the_way",
          riderId: "rider-1",
        },
        target: "customer",
        actor: { id: "rider-1", role: "rider" },
      })
    ).toThrow(DeliveryCodeResendRouteError);

    deps.getResendAvailability.mockReturnValue({
      allowed: false,
      status: 429,
      message: "Try later",
      code: "DELIVERY_CODE_RESEND_THROTTLED",
      retryAfterSeconds: 30,
    });

    expect(() =>
      helpers.ensureDeliveryCodeResendAllowed({
        order: {
          id: "order-1",
          isGiftOrder: true,
          deliveryVerificationRequired: true,
          deliveryCodeEncrypted: "cipher",
          status: "on_the_way",
          riderId: "rider-1",
        },
        target: "recipient",
        actor: { id: "rider-1", role: "rider" },
      })
    ).toThrow(DeliveryCodeResendRouteError);

    try {
      helpers.ensureDeliveryCodeResendAllowed({
        order: {
          id: "order-1",
          isGiftOrder: true,
          deliveryVerificationRequired: true,
          deliveryCodeEncrypted: "cipher",
          status: "on_the_way",
          riderId: "rider-1",
        },
        target: "recipient",
        actor: { id: "rider-1", role: "rider" },
      });
    } catch (error) {
      expect(error.code).toBe("DELIVERY_CODE_RESEND_THROTTLED");
      expect(error.meta).toEqual({ retryAfterSeconds: 30 });
    }
  });

  it("resends the delivery code to the customer and returns the code to the customer actor", async () => {
    prisma.user.findUnique.mockResolvedValue({ phone: "+233555000111" });
    prisma.order.update.mockResolvedValue(undefined);
    deps.sendDeliveryCodeSms.mockResolvedValue({ success: true, provider: "hubtel" });

    const result = await helpers.resendDeliveryCode({
      order: {
        id: "order-2",
        orderNumber: "ORD-2",
        customerId: "cust-1",
        giftRecipientName: "Ama",
        deliveryCodeEncrypted: "cipher",
      },
      target: "customer",
      actor: { id: "cust-1", role: "customer" },
    });

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { id: "cust-1" },
      select: { phone: true },
    });
    expect(deps.sendDeliveryCodeSms).toHaveBeenCalledWith({
      phoneNumber: "+233555000111",
      orderNumber: "ORD-2",
      code: "123456",
      audience: "customer",
      recipientName: "Ama",
    });
    expect(prisma.order.update).toHaveBeenCalledWith({
      where: { id: "order-2" },
      data: {
        deliveryCodeResendCount: { increment: 1 },
        deliveryCodeLastSentAt: expect.any(Date),
      },
    });
    expect(result).toEqual(
      expect.objectContaining({
        orderId: "order-2",
        target: "customer",
        giftDeliveryCode: "123456",
      })
    );
  });

  it("resends the delivery code to the recipient without exposing the code", async () => {
    prisma.order.update.mockResolvedValue(undefined);
    deps.sendDeliveryCodeSms.mockResolvedValue({ success: true, provider: "hubtel" });

    const result = await helpers.resendDeliveryCode({
      order: {
        id: "order-3",
        orderNumber: "ORD-3",
        customerId: "cust-2",
        giftRecipientPhone: "+233555000222",
        giftRecipientName: "Esi",
        deliveryCodeEncrypted: "cipher",
      },
      target: "recipient",
      actor: { id: "admin-1", role: "admin" },
    });

    expect(deps.sendDeliveryCodeSms).toHaveBeenCalledWith({
      phoneNumber: "+233555000222",
      orderNumber: "ORD-3",
      code: "123456",
      audience: "recipient",
      recipientName: "Esi",
    });
    expect(result.giftDeliveryCode).toBeUndefined();
  });

  it("surfaces send failure as a typed route error", async () => {
    deps.sendDeliveryCodeSms.mockResolvedValue({ success: false, message: "Gateway down" });

    await expect(
      helpers.resendDeliveryCode({
        order: {
          id: "order-4",
          orderNumber: "ORD-4",
          customerId: "cust-4",
          giftRecipientPhone: "+233555000444",
          giftRecipientName: "Kojo",
          deliveryCodeEncrypted: "cipher",
        },
        target: "recipient",
        actor: { id: "admin-1", role: "admin" },
      })
    ).rejects.toMatchObject({
      message: "Gateway down",
      status: 502,
      code: "DELIVERY_CODE_RESEND_FAILED",
    });
  });
});
