const {
  OrderPaymentInitializationError,
  createOrderPaystackInitializeHelpers,
} = require("../routes/support/order_paystack_initialize_helpers");

describe("order_paystack_initialize_helpers", () => {
  let prisma;
  let paystackService;
  let getCodExternalPaymentAmount;
  let helpers;

  beforeEach(() => {
    prisma = {
      order: {
        update: jest.fn().mockResolvedValue(undefined),
      },
    };
    paystackService = {
      initializeTransaction: jest.fn().mockResolvedValue({
        authorization_url: "https://paystack.test/auth",
        reference: "paystack-ref-123",
        access_code: "access-code-123",
      }),
    };
    getCodExternalPaymentAmount = jest.fn(() => 12.5);
    helpers = createOrderPaystackInitializeHelpers({
      prisma,
      paystackService,
      getCodExternalPaymentAmount,
    });
  });

  it("rejects already-paid orders", () => {
    expect(() =>
      helpers.ensureOrderCanInitializePayment({
        order: {
          id: "order-1",
          customerId: "cust-1",
          paymentStatus: "paid",
          paymentMethod: "card",
          totalAmount: 50,
        },
        actorId: "cust-1",
        includeRainFee: true,
      })
    ).toThrow(OrderPaymentInitializationError);
  });

  it("computes COD external payment amount and payment scope", () => {
    const result = helpers.ensureOrderCanInitializePayment({
      order: {
        id: "order-2",
        customerId: "cust-2",
        paymentStatus: "pending",
        paymentMethod: "cash",
        totalAmount: 30,
      },
      actorId: "cust-2",
      includeRainFee: false,
    });

    expect(getCodExternalPaymentAmount).toHaveBeenCalledWith(
      {
        id: "order-2",
        customerId: "cust-2",
        paymentStatus: "pending",
        paymentMethod: "cash",
        totalAmount: 30,
      },
      { includeRainFee: false }
    );
    expect(result).toEqual({
      externalPaymentAmount: 12.5,
      paymentScope: "cod_delivery_fee",
    });
  });

  it("initializes paystack, persists payment metadata, and returns response payload", async () => {
    const result = await helpers.initializePaystackPaymentForOrder({
      order: {
        id: "order-3",
        orderNumber: "ORD-3",
        paymentMethod: "card",
      },
      email: "user@example.com",
      externalPaymentAmount: 45.75,
      reference: "ORD-3-fixed-ref",
    });

    expect(paystackService.initializeTransaction).toHaveBeenCalledWith({
      email: "user@example.com",
      amount: 4575,
      reference: "ORD-3-fixed-ref",
      metadata: {
        orderId: "order-3",
        paymentScope: "full_order_payment",
      },
    });
    expect(prisma.order.update).toHaveBeenCalledWith({
      where: { id: "order-3" },
      data: {
        paymentProvider: "paystack",
        paymentReferenceId: "paystack-ref-123",
        paymentStatus: "processing",
      },
    });
    expect(result).toEqual({
      authorizationUrl: "https://paystack.test/auth",
      reference: "paystack-ref-123",
      accessCode: "access-code-123",
      paymentAmount: 45.75,
      paymentScope: "full_order_payment",
    });
  });
});
