const {
  createOrderDeliveryVerificationHelpers,
} = require("../routes/support/order_delivery_verification_helpers");

describe("order_delivery_verification_helpers", () => {
  class TestDeliveryVerificationError extends Error {
    constructor(message, status, code, meta) {
      super(message);
      this.status = status;
      this.code = code;
      this.meta = meta;
    }
  }

  let verifyDeliveryCodeOrThrow;
  let helpers;

  beforeEach(() => {
    verifyDeliveryCodeOrThrow = jest.fn();
    helpers = createOrderDeliveryVerificationHelpers({
      DeliveryVerificationError: TestDeliveryVerificationError,
      verifyDeliveryCodeOrThrow,
    });
  });

  it("rejects missing verification payload for delivered orders that require it", () => {
    expect(() =>
      helpers.ensureDeliveryVerificationPayload({
        status: "delivered",
        order: { deliveryVerificationRequired: true },
        deliveryVerification: null,
      })
    ).toThrow(TestDeliveryVerificationError);

    try {
      helpers.ensureDeliveryVerificationPayload({
        status: "delivered",
        order: { deliveryVerificationRequired: true },
        deliveryVerification: null,
      });
    } catch (error) {
      expect(error.code).toBe("DELIVERY_VERIFICATION_REQUIRED");
    }
  });

  it("resolves code verification update data through the delivery verification service", async () => {
    verifyDeliveryCodeOrThrow.mockResolvedValue({ deliveryCodeVerifiedAt: new Date("2026-03-10T12:00:00Z") });

    const result = await helpers.resolveCodeVerificationUpdateData({
      tx: { prisma: true },
      status: "delivered",
      order: { id: "order-1", deliveryVerificationRequired: true },
      deliveryVerification: { method: "code", code: "123456", riderLat: 5.6, riderLng: -0.2 },
      actorId: "rider-1",
      actorRole: "rider",
    });

    expect(verifyDeliveryCodeOrThrow).toHaveBeenCalledWith({
      tx: { prisma: true },
      order: { id: "order-1", deliveryVerificationRequired: true },
      code: "123456",
      actorId: "rider-1",
      actorRole: "rider",
      riderLat: 5.6,
      riderLng: -0.2,
      skipSuccessAudit: true,
    });
    expect(result).toEqual({ deliveryCodeVerifiedAt: new Date("2026-03-10T12:00:00Z") });
  });

  it("applies code-based delivery verification updates and writes an audit", async () => {
    const tx = {
      order: {
        findUnique: jest.fn().mockResolvedValue({
          id: "order-1",
          deliveryCodeVerifiedAt: null,
          deliveryVerificationMethod: null,
        }),
      },
      orderActionAudit: {
        create: jest.fn().mockResolvedValue(undefined),
      },
    };

    const updateData = await helpers.applyDeliveredVerificationUpdate({
      tx,
      orderId: "order-1",
      order: { deliveryVerificationRequired: true },
      deliveryVerification: { method: "code", riderLat: "5.55", riderLng: "-0.20" },
      codeVerificationUpdateData: { deliveryCodeVerifiedAt: new Date("2026-03-10T12:00:00Z") },
      updateData: { status: "delivered" },
      actorId: "rider-1",
      actorRole: "rider",
    });

    expect(updateData).toEqual({
      status: "delivered",
      deliveryCodeVerifiedAt: new Date("2026-03-10T12:00:00Z"),
    });
    expect(tx.orderActionAudit.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orderId: "order-1",
        actorId: "rider-1",
        actorRole: "rider",
        action: "gift_code_verified",
        metadata: expect.objectContaining({ riderLat: 5.55, riderLng: -0.2 }),
      }),
    });
  });

  it("applies authorized photo verification updates and writes fallback audit", async () => {
    const tx = {
      order: {
        findUnique: jest.fn().mockResolvedValue({
          id: "order-2",
          deliveryCodeVerifiedAt: null,
          deliveryVerificationMethod: null,
        }),
      },
      orderActionAudit: {
        create: jest.fn().mockResolvedValue(undefined),
      },
    };

    const updateData = await helpers.applyDeliveredVerificationUpdate({
      tx,
      orderId: "order-2",
      order: { deliveryVerificationRequired: true },
      deliveryVerification: {
        method: "authorized_photo",
        photoUrl: " https://cdn.example/photo.jpg ",
        reason: " Recipient unavailable ",
        contactAttempted: true,
        authorizedRecipientName: "Ama",
        riderLat: "5.6",
        riderLng: "-0.1",
      },
      codeVerificationUpdateData: null,
      updateData: { status: "delivered" },
      actorId: "rider-2",
      actorRole: "rider",
    });

    expect(updateData).toEqual(
      expect.objectContaining({
        status: "delivered",
        deliveryVerificationMethod: "authorized_photo",
        deliveryProofPhotoUrl: "https://cdn.example/photo.jpg",
        deliveryProofReason: "Recipient unavailable",
        deliveryVerificationLat: 5.6,
        deliveryVerificationLng: -0.1,
      })
    );
    expect(updateData.deliveryProofCapturedAt).toBeInstanceOf(Date);
    expect(tx.orderActionAudit.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "gift_delivered_fallback",
        metadata: expect.objectContaining({
          reason: "Recipient unavailable",
          photoUrl: "https://cdn.example/photo.jpg",
          contactAttempted: true,
          authorizedRecipientName: "Ama",
          riderLat: 5.6,
          riderLng: -0.1,
        }),
      }),
    });
  });

  it("rejects already-completed verification state", async () => {
    const tx = {
      order: {
        findUnique: jest.fn().mockResolvedValue({
          id: "order-3",
          deliveryCodeVerifiedAt: new Date(),
          deliveryVerificationMethod: null,
        }),
      },
      orderActionAudit: {
        create: jest.fn(),
      },
    };

    await expect(
      helpers.applyDeliveredVerificationUpdate({
        tx,
        orderId: "order-3",
        order: { deliveryVerificationRequired: true },
        deliveryVerification: { method: "code" },
        codeVerificationUpdateData: { deliveryCodeVerifiedAt: new Date() },
        updateData: { status: "delivered" },
        actorId: "rider-3",
        actorRole: "rider",
      })
    ).rejects.toMatchObject({ code: "DELIVERY_VERIFICATION_ALREADY_COMPLETED" });
  });
});
