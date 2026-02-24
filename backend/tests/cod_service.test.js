const {
  CodPolicyError,
  COD_NO_SHOW_REASON,
  isCodNoShowReason,
  getCodExternalPaymentAmount,
  getCodRemainingCashAmount,
  validateCodNoShowEvidence,
  evaluateCodEligibility,
} = require("../services/cod_service");

describe("cod_service", () => {
  it("matches supported no-show reason aliases", () => {
    expect(isCodNoShowReason("cod_no_show_confirmed")).toBe(true);
    expect(isCodNoShowReason("customer_no_show")).toBe(true);
    expect(isCodNoShowReason("other_reason")).toBe(false);
  });

  it("computes COD upfront and remaining amounts", () => {
    const order = { totalAmount: 42.65, deliveryFee: 8.25, rainFee: 1.4 };
    expect(getCodExternalPaymentAmount(order)).toBe(8.25);
    expect(getCodExternalPaymentAmount(order, { includeRainFee: true })).toBe(9.65);
    expect(getCodRemainingCashAmount(order)).toBe(34.4);
    expect(getCodRemainingCashAmount(order, { includeRainFee: true })).toBe(33);
  });

  it("rejects invalid no-show evidence", () => {
    expect(() =>
      validateCodNoShowEvidence({
        photoUrl: "",
        contactAttempts: 1,
        waitedMinutes: 2,
      })
    ).toThrow(CodPolicyError);
  });

  it("accepts valid no-show evidence", () => {
    const evidence = validateCodNoShowEvidence({
      photoUrl: "https://cdn.example.com/photo.jpg",
      contactAttempts: 2,
      waitedMinutes: 6,
      riderLat: 5.6037,
      riderLng: -0.187,
    });

    expect(evidence.photoUrl).toBe("https://cdn.example.com/photo.jpg");
    expect(evidence.contactAttempts).toBe(2);
    expect(evidence.waitedMinutes).toBe(6);
    expect(evidence.riderLat).toBeCloseTo(5.6037);
    expect(evidence.riderLng).toBeCloseTo(-0.187);
  });

  it("returns ineligible when phone is not verified", async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: "user_1",
          isActive: true,
          phone: "+233501234567",
          isPhoneVerified: false,
        }),
      },
      order: {
        count: jest
          .fn()
          .mockResolvedValueOnce(5) // prepaid delivered
          .mockResolvedValueOnce(0) // confirmed no-shows
          .mockResolvedValueOnce(0), // active COD
      },
    };

    const result = await evaluateCodEligibility({
      prisma,
      customerId: "user_1",
      minPrepaidDeliveredOrders: 3,
      requirePhoneVerified: true,
    });

    expect(result.eligible).toBe(false);
    expect(result.code).toBe("COD_PHONE_NOT_VERIFIED");
  });

  it("returns ineligible when trust threshold is not met", async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: "user_1",
          isActive: true,
          phone: "+233501234567",
          isPhoneVerified: true,
        }),
      },
      order: {
        count: jest
          .fn()
          .mockResolvedValueOnce(1)
          .mockResolvedValueOnce(0)
          .mockResolvedValueOnce(0),
      },
    };

    const result = await evaluateCodEligibility({
      prisma,
      customerId: "user_1",
      minPrepaidDeliveredOrders: 3,
    });

    expect(result.eligible).toBe(false);
    expect(result.code).toBe("COD_TRUST_THRESHOLD_NOT_MET");
  });

  it("returns ineligible when customer has confirmed COD no-show", async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: "user_1",
          isActive: true,
          phone: "+233501234567",
          isPhoneVerified: true,
        }),
      },
      order: {
        count: jest
          .fn()
          .mockResolvedValueOnce(4)
          .mockResolvedValueOnce(1)
          .mockResolvedValueOnce(0),
      },
    };

    const result = await evaluateCodEligibility({
      prisma,
      customerId: "user_1",
      minPrepaidDeliveredOrders: 3,
      noShowDisableThreshold: 1,
    });

    expect(result.eligible).toBe(false);
    expect(result.code).toBe("COD_DISABLED_NO_SHOW");
  });

  it("returns ineligible when active COD order exists", async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: "user_1",
          isActive: true,
          phone: "+233501234567",
          isPhoneVerified: true,
        }),
      },
      order: {
        count: jest
          .fn()
          .mockResolvedValueOnce(4)
          .mockResolvedValueOnce(0)
          .mockResolvedValueOnce(1),
      },
    };

    const result = await evaluateCodEligibility({
      prisma,
      customerId: "user_1",
      maxConcurrentCodOrders: 1,
    });

    expect(result.eligible).toBe(false);
    expect(result.code).toBe("COD_ACTIVE_ORDER_EXISTS");
  });

  it("returns eligible when all checks pass", async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: "user_1",
          isActive: true,
          phone: "+233501234567",
          isPhoneVerified: true,
        }),
      },
      order: {
        count: jest
          .fn()
          .mockResolvedValueOnce(4)
          .mockResolvedValueOnce(0)
          .mockResolvedValueOnce(0),
      },
    };

    const result = await evaluateCodEligibility({
      prisma,
      customerId: "user_1",
      minPrepaidDeliveredOrders: 3,
      noShowDisableThreshold: 1,
    });

    expect(result.eligible).toBe(true);
    expect(result.code).toBe("COD_ELIGIBLE");
    expect(result.metrics.confirmedNoShows).toBe(0);
    expect(COD_NO_SHOW_REASON).toBe("cod_no_show_confirmed");
  });
});
