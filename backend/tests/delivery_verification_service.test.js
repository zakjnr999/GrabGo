const {
  generateDeliveryCode,
  hashDeliveryCode,
  encryptDeliveryCode,
  decryptDeliveryCode,
  getResendAvailability,
  isDeliveryCodeLocked,
  verifyDeliveryCodeOrThrow,
} = require("../services/delivery_verification_service");

describe("delivery_verification_service", () => {
  it("generates a 4-digit code", () => {
    const code = generateDeliveryCode();
    expect(code).toMatch(/^\d{4}$/);
  });

  it("hashes deterministically by order id + code", () => {
    const first = hashDeliveryCode("order_123", "4821");
    const second = hashDeliveryCode("order_123", "4821");
    const different = hashDeliveryCode("order_124", "4821");

    expect(first).toEqual(second);
    expect(first).not.toEqual(different);
  });

  it("encrypts and decrypts delivery code", () => {
    const encrypted = encryptDeliveryCode("4821");
    const decrypted = decryptDeliveryCode(encrypted);
    expect(decrypted).toEqual("4821");
  });

  it("flags lock when lock timestamp is in the future", () => {
    const order = {
      deliveryCodeLockedUntil: new Date(Date.now() + 60_000),
    };
    expect(isDeliveryCodeLocked(order)).toBe(true);
  });

  it("allows resend when limits are not exceeded", () => {
    const order = {
      deliveryCodeResendCount: 0,
      deliveryCodeLastSentAt: new Date(Date.now() - 61_000),
      deliveryCodeVerifiedAt: null,
      deliveryVerificationMethod: null,
    };

    const result = getResendAvailability(order);
    expect(result.allowed).toBe(true);
  });

  it("blocks resend during cooldown", () => {
    const order = {
      deliveryCodeResendCount: 0,
      deliveryCodeLastSentAt: new Date(),
      deliveryCodeVerifiedAt: null,
      deliveryVerificationMethod: null,
    };

    const result = getResendAvailability(order);
    expect(result.allowed).toBe(false);
    expect(result.code).toEqual("DELIVERY_CODE_RESEND_COOLDOWN");
  });

  it("increments failed attempts atomically on invalid verification code", async () => {
    const tx = {
      order: {
        findUnique: jest.fn().mockResolvedValue({
          id: "order_1",
          riderId: "rider_1",
          deliveryCodeHash: hashDeliveryCode("order_1", "4821"),
          deliveryCodeFailedAttempts: 0,
          deliveryCodeLockedUntil: null,
          deliveryCodeVerifiedAt: null,
          deliveryVerificationMethod: null,
        }),
        update: jest
          .fn()
          .mockResolvedValueOnce({ deliveryCodeFailedAttempts: 1 }),
      },
      orderActionAudit: {
        create: jest.fn().mockResolvedValue({ id: "audit_1" }),
      },
    };

    await expect(
      verifyDeliveryCodeOrThrow({
        tx,
        order: { id: "order_1" },
        code: "0000",
        actorId: "rider_1",
        actorRole: "rider",
      })
    ).rejects.toMatchObject({ code: "DELIVERY_CODE_INVALID" });

    expect(tx.order.findUnique).toHaveBeenCalledTimes(1);
    expect(tx.order.update).toHaveBeenCalledWith({
      where: { id: "order_1" },
      data: { deliveryCodeFailedAttempts: { increment: 1 } },
      select: { deliveryCodeFailedAttempts: true },
    });
  });

  it("rejects verification when latest order state is already verified", async () => {
    const tx = {
      order: {
        findUnique: jest.fn().mockResolvedValue({
          id: "order_1",
          riderId: "rider_1",
          deliveryCodeHash: hashDeliveryCode("order_1", "4821"),
          deliveryCodeFailedAttempts: 0,
          deliveryCodeLockedUntil: null,
          deliveryCodeVerifiedAt: new Date(),
          deliveryVerificationMethod: "code",
        }),
        update: jest.fn(),
      },
      orderActionAudit: {
        create: jest.fn(),
      },
    };

    await expect(
      verifyDeliveryCodeOrThrow({
        tx,
        order: { id: "order_1" },
        code: "4821",
      })
    ).rejects.toMatchObject({ code: "DELIVERY_VERIFICATION_ALREADY_COMPLETED" });

    expect(tx.order.update).not.toHaveBeenCalled();
    expect(tx.orderActionAudit.create).not.toHaveBeenCalled();
  });
});
