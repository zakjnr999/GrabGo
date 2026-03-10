class OrderPaymentInitializationError extends Error {
  constructor(message, status = 400, code = null) {
    super(message);
    this.name = "OrderPaymentInitializationError";
    this.status = status;
    this.code = code;
  }
}

const createOrderPaystackInitializeHelpers = ({
  prisma,
  paystackService,
  getCodExternalPaymentAmount,
}) => {
  const ensureOrderCanInitializePayment = ({ order, actorId, includeRainFee }) => {
    if (!order) {
      throw new OrderPaymentInitializationError("Order not found", 404);
    }

    if (order.customerId !== actorId) {
      throw new OrderPaymentInitializationError(
        "Not authorized to initialize payment for this order",
        403
      );
    }

    if (["paid", "successful"].includes(order.paymentStatus)) {
      throw new OrderPaymentInitializationError("Order already paid", 400);
    }

    const externalPaymentAmount =
      order.paymentMethod === "cash"
        ? getCodExternalPaymentAmount(order, { includeRainFee })
        : Number(order.totalAmount || 0);

    if (externalPaymentAmount <= 0) {
      throw new OrderPaymentInitializationError(
        "Order does not require external payment",
        400
      );
    }

    return {
      externalPaymentAmount,
      paymentScope:
        order.paymentMethod === "cash" ? "cod_delivery_fee" : "full_order_payment",
    };
  };

  const initializePaystackPaymentForOrder = async ({
    order,
    email,
    externalPaymentAmount,
    reference,
  }) => {
    if (!email) {
      throw new OrderPaymentInitializationError("User email is required for Paystack", 400);
    }

    const paymentReference = reference || `ORD-${order.orderNumber}-${Date.now()}`;
    const amount = Math.round(externalPaymentAmount * 100);
    const paymentScope =
      order.paymentMethod === "cash" ? "cod_delivery_fee" : "full_order_payment";

    const init = await paystackService.initializeTransaction({
      email,
      amount,
      reference: paymentReference,
      metadata: {
        orderId: order.id,
        paymentScope,
      },
    });

    const resolvedReference = init.reference || paymentReference;

    await prisma.order.update({
      where: { id: order.id },
      data: {
        paymentProvider: "paystack",
        paymentReferenceId: resolvedReference,
        paymentStatus: "processing",
      },
    });

    return {
      authorizationUrl: init.authorization_url,
      reference: resolvedReference,
      accessCode: init.access_code,
      paymentAmount: externalPaymentAmount,
      paymentScope,
    };
  };

  return {
    ensureOrderCanInitializePayment,
    initializePaystackPaymentForOrder,
  };
};

module.exports = {
  OrderPaymentInitializationError,
  createOrderPaystackInitializeHelpers,
};
