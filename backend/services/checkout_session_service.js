const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');
const creditService = require('./credit_service');
const paystackService = require('./paystack_service');
const dispatchService = require('./dispatch_service');
const { createOrderAudit } = require('./pickup_order_service');
const { getUserCartGroups } = require('./cart_service');
const { calculateCartGroupsPricing } = require('./pricing_service');

const roundCurrency = (value) => Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;

class CheckoutSessionError extends Error {
  constructor(message, { code = 'CHECKOUT_SESSION_ERROR', status = 400, meta = null } = {}) {
    super(message);
    this.name = 'CheckoutSessionError';
    this.code = code;
    this.status = status;
    this.meta = meta;
  }
}

const normalizeFulfillmentMode = (mode) => {
  if (!mode) return 'delivery';
  return String(mode).trim().toLowerCase() === 'pickup' ? 'pickup' : 'delivery';
};

const normalizePaymentMethod = (method) => {
  if (!method) return 'card';
  return String(method).trim().toLowerCase();
};

const generateGroupOrderNumber = async () => {
  const timestamp = Date.now();
  let attempt = 0;
  while (attempt < 10) {
    const random = Math.floor(Math.random() * 10000)
      .toString()
      .padStart(4, '0');
    const groupOrderNumber = `GRP-${timestamp}-${random}`;
    const existing = await prisma.checkoutSession.findUnique({
      where: { groupOrderNumber },
      select: { id: true },
    });
    if (!existing) return groupOrderNumber;
    attempt += 1;
  }
  throw new CheckoutSessionError('Failed to generate a unique group order number', {
    code: 'GROUP_ORDER_NUMBER_GENERATION_FAILED',
    status: 500,
  });
};

const generateOrderNumber = async () => {
  const timestamp = Date.now();
  let attempt = 0;
  while (attempt < 10) {
    const random = Math.floor(Math.random() * 10000)
      .toString()
      .padStart(4, '0');
    const orderNumber = `ORD-${timestamp}-${random}`;
    const existing = await prisma.order.findUnique({
      where: { orderNumber },
      select: { id: true },
    });
    if (!existing) return orderNumber;
    attempt += 1;
  }
  throw new CheckoutSessionError('Failed to generate order number', {
    code: 'ORDER_NUMBER_GENERATION_FAILED',
    status: 500,
  });
};

const isDispatchableStatus = (status) => {
  if (status === 'preparing' || status === 'ready') return true;
  if (status === 'confirmed' && featureFlags.isConfirmedPredispatchEnabled) return true;
  return false;
};

const resolveVendorContextFromCart = (cart) => {
  if (!cart) return null;
  if (cart.cartType === 'food') {
    return {
      orderType: 'food',
      vendorField: 'restaurantId',
      vendorId: cart.restaurantId,
      vendorName:
        cart.items?.find((item) => item.food?.restaurant)?.food?.restaurant?.restaurantName || null,
      vendorData: cart.items?.find((item) => item.food?.restaurant)?.food?.restaurant || null,
    };
  }
  if (cart.cartType === 'grocery') {
    return {
      orderType: 'grocery',
      vendorField: 'groceryStoreId',
      vendorId: cart.groceryStoreId,
      vendorName:
        cart.items?.find((item) => item.groceryItem?.store)?.groceryItem?.store?.storeName || null,
      vendorData: cart.items?.find((item) => item.groceryItem?.store)?.groceryItem?.store || null,
    };
  }
  if (cart.cartType === 'pharmacy') {
    return {
      orderType: 'pharmacy',
      vendorField: 'pharmacyStoreId',
      vendorId: cart.pharmacyStoreId,
      vendorName:
        cart.items?.find((item) => item.pharmacyItem?.store)?.pharmacyItem?.store?.storeName || null,
      vendorData: cart.items?.find((item) => item.pharmacyItem?.store)?.pharmacyItem?.store || null,
    };
  }
  if (cart.cartType === 'grabmart') {
    return {
      orderType: 'grabmart',
      vendorField: 'grabMartStoreId',
      vendorId: cart.grabMartStoreId,
      vendorName:
        cart.items?.find((item) => item.grabMartItem?.store)?.grabMartItem?.store?.storeName || null,
      vendorData: cart.items?.find((item) => item.grabMartItem?.store)?.grabMartItem?.store || null,
    };
  }
  return null;
};

const validateVendorState = (vendorData, vendorName = 'Vendor') => {
  if (!vendorData) {
    throw new CheckoutSessionError(`${vendorName} was not found`, {
      code: 'CHECKOUT_VENDOR_NOT_FOUND',
      status: 404,
    });
  }
  if (vendorData.status && String(vendorData.status).toLowerCase() !== 'approved') {
    throw new CheckoutSessionError(`${vendorName} is not active`, {
      code: 'CHECKOUT_VENDOR_INACTIVE',
      status: 400,
    });
  }
  if (vendorData.isDeleted === true) {
    throw new CheckoutSessionError(`${vendorName} is unavailable`, {
      code: 'CHECKOUT_VENDOR_DELETED',
      status: 400,
    });
  }
  if (vendorData.isAcceptingOrders === false) {
    throw new CheckoutSessionError(`${vendorName} is not accepting orders right now`, {
      code: 'CHECKOUT_VENDOR_NOT_ACCEPTING',
      status: 400,
    });
  }
  if (vendorData.isOpen === false) {
    throw new CheckoutSessionError(`${vendorName} is currently closed`, {
      code: 'CHECKOUT_VENDOR_CLOSED',
      status: 400,
    });
  }
};

const validateCartItemState = (cartItem) => {
  if (!cartItem) return;
  if (cartItem.itemType === 'Food') {
    if (!cartItem.food || cartItem.food.isAvailable !== true) {
      throw new CheckoutSessionError(`${cartItem.name || 'An item'} is currently unavailable`, {
        code: 'CHECKOUT_ITEM_UNAVAILABLE',
        status: 400,
      });
    }
    if (Array.isArray(cartItem.food.portionOptions) && cartItem.food.portionOptions.length > 0) {
      const selectedPortionId = cartItem.selectedPortion && typeof cartItem.selectedPortion === 'object'
        ? cartItem.selectedPortion.id
        : null;
      if (!selectedPortionId) {
        throw new CheckoutSessionError(`Please re-add ${cartItem.name || 'this item'} with a portion selection`, {
          code: 'CHECKOUT_ITEM_CUSTOMIZATION_REQUIRED',
          status: 400,
        });
      }
    }
    return;
  }

  if (cartItem.itemType === 'GroceryItem') {
    if (!cartItem.groceryItem || cartItem.groceryItem.isAvailable !== true) {
      throw new CheckoutSessionError(`${cartItem.name || 'An item'} is currently unavailable`, {
        code: 'CHECKOUT_ITEM_UNAVAILABLE',
        status: 400,
      });
    }
    if (Number.isFinite(cartItem.groceryItem.stock) && cartItem.quantity > cartItem.groceryItem.stock) {
      throw new CheckoutSessionError(`Not enough stock for ${cartItem.name || 'this item'}`, {
        code: 'CHECKOUT_ITEM_OUT_OF_STOCK',
        status: 400,
      });
    }
    return;
  }

  if (cartItem.itemType === 'PharmacyItem') {
    if (!cartItem.pharmacyItem || cartItem.pharmacyItem.isAvailable !== true) {
      throw new CheckoutSessionError(`${cartItem.name || 'An item'} is currently unavailable`, {
        code: 'CHECKOUT_ITEM_UNAVAILABLE',
        status: 400,
      });
    }
    if (Number.isFinite(cartItem.pharmacyItem.stock) && cartItem.quantity > cartItem.pharmacyItem.stock) {
      throw new CheckoutSessionError(`Not enough stock for ${cartItem.name || 'this item'}`, {
        code: 'CHECKOUT_ITEM_OUT_OF_STOCK',
        status: 400,
      });
    }
    return;
  }

  if (cartItem.itemType === 'GrabMartItem') {
    if (!cartItem.grabMartItem || cartItem.grabMartItem.isAvailable !== true) {
      throw new CheckoutSessionError(`${cartItem.name || 'An item'} is currently unavailable`, {
        code: 'CHECKOUT_ITEM_UNAVAILABLE',
        status: 400,
      });
    }
    if (Number.isFinite(cartItem.grabMartItem.stock) && cartItem.quantity > cartItem.grabMartItem.stock) {
      throw new CheckoutSessionError(`Not enough stock for ${cartItem.name || 'this item'}`, {
        code: 'CHECKOUT_ITEM_OUT_OF_STOCK',
        status: 400,
      });
    }
  }
};

const toOrderItemCreate = (cartItem) => {
  const data = {
    itemType: cartItem.itemType,
    name: cartItem.name,
    quantity: cartItem.quantity,
    price: cartItem.price,
    image: cartItem.imageUrl || null,
    selectedPortion: cartItem.selectedPortion || null,
    selectedPreferences: cartItem.selectedPreferences || null,
    itemNote: cartItem.itemNote || null,
    customizationKey: cartItem.customizationKey || null,
  };

  if (cartItem.itemType === 'Food') data.foodId = cartItem.foodId;
  if (cartItem.itemType === 'GroceryItem') data.groceryItemId = cartItem.groceryItemId;
  if (cartItem.itemType === 'PharmacyItem') data.pharmacyItemId = cartItem.pharmacyItemId;
  if (cartItem.itemType === 'GrabMartItem') data.grabMartItemId = cartItem.grabMartItemId;

  return data;
};

const normalizeDeliveryAddress = (deliveryAddress) => {
  if (!deliveryAddress || typeof deliveryAddress !== 'object') return null;
  const street = String(deliveryAddress.street || '').trim();
  const city = String(deliveryAddress.city || '').trim();
  if (!street || !city) return null;

  const latitude = Number(deliveryAddress.latitude);
  const longitude = Number(deliveryAddress.longitude);

  return {
    street,
    city,
    state: deliveryAddress.state ? String(deliveryAddress.state).trim() : null,
    zipCode: deliveryAddress.zipCode ? String(deliveryAddress.zipCode).trim() : null,
    latitude: Number.isFinite(latitude) ? latitude : null,
    longitude: Number.isFinite(longitude) ? longitude : null,
  };
};

const allocateCredits = (groups, totalCreditsApplied) => {
  const allocations = new Map();
  let remaining = roundCurrency(totalCreditsApplied);

  for (let i = 0; i < groups.length; i += 1) {
    const group = groups[i];
    const groupTotal = roundCurrency(group?.pricing?.total || 0);
    if (remaining <= 0 || groupTotal <= 0) {
      allocations.set(group.cart.id, 0);
      continue;
    }

    if (i === groups.length - 1) {
      const finalAmount = roundCurrency(Math.min(remaining, groupTotal));
      allocations.set(group.cart.id, finalAmount);
      remaining = roundCurrency(remaining - finalAmount);
      continue;
    }

    const applied = roundCurrency(Math.min(groupTotal, remaining));
    allocations.set(group.cart.id, applied);
    remaining = roundCurrency(remaining - applied);
  }

  return allocations;
};

const createCheckoutSession = async ({ customer, payload }) => {
  if (!featureFlags.isMixedCheckoutEnabled) {
    throw new CheckoutSessionError('Mixed checkout is currently unavailable', {
      code: 'MIXED_CHECKOUT_DISABLED',
      status: 403,
    });
  }

  if (!featureFlags.isMixedCartEnabled) {
    throw new CheckoutSessionError('Mixed cart is currently unavailable', {
      code: 'MIXED_CART_DISABLED',
      status: 403,
    });
  }

  const fulfillmentMode = normalizeFulfillmentMode(payload?.fulfillmentMode);
  if (fulfillmentMode !== 'delivery') {
    throw new CheckoutSessionError('Mixed checkout supports delivery orders only', {
      code: 'MIXED_CHECKOUT_DELIVERY_ONLY',
      status: 400,
    });
  }

  const paymentMethod = normalizePaymentMethod(payload?.paymentMethod);
  if (paymentMethod !== 'card') {
    throw new CheckoutSessionError('Mixed checkout supports card payment only', {
      code: 'MIXED_CHECKOUT_CARD_ONLY',
      status: 400,
    });
  }

  if (payload?.isGiftOrder === true) {
    throw new CheckoutSessionError('Gift orders are unavailable for mixed checkout', {
      code: 'MIXED_CHECKOUT_GIFT_NOT_SUPPORTED',
      status: 400,
    });
  }

  if (String(payload?.deliveryTimeType || '').toLowerCase() === 'scheduled' || payload?.scheduledForAt) {
    throw new CheckoutSessionError('Scheduled delivery is unavailable for mixed checkout', {
      code: 'MIXED_CHECKOUT_SCHEDULED_NOT_SUPPORTED',
      status: 400,
    });
  }

  const normalizedAddress = normalizeDeliveryAddress(payload?.deliveryAddress);
  if (!normalizedAddress) {
    throw new CheckoutSessionError('A valid shared delivery address is required', {
      code: 'MIXED_CHECKOUT_DELIVERY_ADDRESS_REQUIRED',
      status: 400,
    });
  }

  const cartGroups = await getUserCartGroups(customer.id, fulfillmentMode);
  if (!Array.isArray(cartGroups) || cartGroups.length < 2) {
    throw new CheckoutSessionError('Mixed checkout requires at least two vendor groups in cart', {
      code: 'MIXED_CHECKOUT_MIN_GROUPS_NOT_MET',
      status: 400,
    });
  }

  for (const cart of cartGroups) {
    const vendorContext = resolveVendorContextFromCart(cart);
    if (!vendorContext?.vendorId) {
      throw new CheckoutSessionError('Could not resolve vendor for one cart group', {
        code: 'MIXED_CHECKOUT_VENDOR_RESOLUTION_FAILED',
        status: 400,
      });
    }

    validateVendorState(vendorContext.vendorData, vendorContext.vendorName || 'Vendor');

    for (const cartItem of cart.items || []) {
      validateCartItemState(cartItem);
    }
  }

  const groupedPricing = await calculateCartGroupsPricing(cartGroups, {
    userId: customer.id,
    deliveryLocation: {
      latitude: normalizedAddress.latitude,
      longitude: normalizedAddress.longitude,
    },
    useCredits: payload?.useCredits !== false,
    fulfillmentMode,
  });

  const pricedGroups = (groupedPricing?.groups || []).map((group) => ({
    cart: group,
    pricing: group?.pricing || null,
  }));

  const summary = groupedPricing?.summary || {};
  const totalBeforeCredits = roundCurrency(
    (summary.subtotal || 0) +
      (summary.deliveryFee || 0) +
      (summary.serviceFee || 0) +
      (summary.tax || 0) +
      (summary.rainFee || 0)
  );
  const totalAfterCredits = roundCurrency(summary.total || totalBeforeCredits);
  const creditsApplied = roundCurrency(summary.creditsApplied || 0);

  const groupOrderNumber = await generateGroupOrderNumber();
  const sessionExpiresAt = new Date(Date.now() + 30 * 60 * 1000);
  const creditAllocationsByCartId = allocateCredits(pricedGroups, creditsApplied);

  const created = await prisma.$transaction(async (tx) => {
    const session = await tx.checkoutSession.create({
      data: {
        groupOrderNumber,
        customerId: customer.id,
        fulfillmentMode,
        paymentMethod: paymentMethod,
        paymentStatus: 'pending',
        status: 'pending',
        subtotal: roundCurrency(summary.subtotal || 0),
        deliveryFee: roundCurrency(summary.deliveryFee || 0),
        serviceFee: roundCurrency(summary.serviceFee || 0),
        tax: roundCurrency(summary.tax || 0),
        rainFee: roundCurrency(summary.rainFee || 0),
        totalAmount: totalAfterCredits,
        creditsApplied,
        vendorCount: pricedGroups.length,
        notes: payload?.notes ? String(payload.notes).trim() : null,
        restrictions: {
          mixedCheckout: true,
          codAllowed: false,
          giftAllowed: false,
          scheduledAllowed: false,
          sharedAddress: true,
        },
        deliveryStreet: normalizedAddress.street,
        deliveryCity: normalizedAddress.city,
        deliveryState: normalizedAddress.state,
        deliveryZipCode: normalizedAddress.zipCode,
        deliveryLatitude: normalizedAddress.latitude,
        deliveryLongitude: normalizedAddress.longitude,
        expiresAt: sessionExpiresAt,
      },
    });

    const childOrders = [];

    for (const group of pricedGroups) {
      const cart = group.cart;
      const pricing = group.pricing || {};
      const vendorContext = resolveVendorContextFromCart(cart);
      const creditsForGroup = roundCurrency(creditAllocationsByCartId.get(cart.id) || 0);
      const groupTotalBeforeCredits = roundCurrency(pricing.total || 0);
      const groupTotalAfterCredits = roundCurrency(Math.max(0, groupTotalBeforeCredits - creditsForGroup));
      const orderNumber = await generateOrderNumber();

      const orderData = {
        orderNumber,
        orderType: vendorContext.orderType,
        fulfillmentMode,
        customerId: customer.id,
        checkoutSessionId: session.id,
        groupId: session.id,
        groupOrderNumber: session.groupOrderNumber,
        isGroupedOrder: true,
        subtotal: roundCurrency(pricing.subtotal || 0),
        deliveryFee: roundCurrency(pricing.deliveryFee || 0),
        rainFee: roundCurrency(pricing.rainFee || 0),
        tax: roundCurrency(pricing.tax || 0),
        totalAmount: groupTotalAfterCredits,
        creditsApplied: creditsForGroup,
        paymentMethod: 'card',
        paymentStatus: 'pending',
        status: 'pending',
        notes: payload?.notes ? String(payload.notes).trim() : null,
        deliveryStreet: normalizedAddress.street,
        deliveryCity: normalizedAddress.city,
        deliveryState: normalizedAddress.state,
        deliveryZipCode: normalizedAddress.zipCode,
        deliveryLatitude: normalizedAddress.latitude,
        deliveryLongitude: normalizedAddress.longitude,
        items: {
          create: (cart.items || []).map((item) => toOrderItemCreate(item)),
        },
        [vendorContext.vendorField]: vendorContext.vendorId,
      };

      const order = await tx.order.create({
        data: orderData,
        select: {
          id: true,
          orderNumber: true,
          orderType: true,
          status: true,
          paymentStatus: true,
          totalAmount: true,
          deliveryFee: true,
          rainFee: true,
          creditsApplied: true,
          checkoutSessionId: true,
          groupId: true,
          groupOrderNumber: true,
        },
      });

      if (creditsForGroup > 0) {
        await tx.userCreditHold.create({
          data: {
            userId: customer.id,
            orderId: order.id,
            amount: creditsForGroup,
            expiresAt: sessionExpiresAt,
          },
        });
      }

      childOrders.push(order);
    }

    return { session, childOrders };
  });

  return {
    session: created.session,
    childOrders: created.childOrders,
    summary: {
      subtotal: roundCurrency(summary.subtotal || 0),
      deliveryFee: roundCurrency(summary.deliveryFee || 0),
      serviceFee: roundCurrency(summary.serviceFee || 0),
      tax: roundCurrency(summary.tax || 0),
      rainFee: roundCurrency(summary.rainFee || 0),
      totalBeforeCredits,
      creditsApplied,
      total: totalAfterCredits,
      vendorCount: pricedGroups.length,
      itemCount: Number(summary.itemCount || 0),
      paymentStatus: 'pending',
      availableBalance: Number(summary.availableBalance || 0),
      creditBalance: Number(summary.creditBalance || 0),
    },
  };
};

const initializeCheckoutSessionPayment = async ({ sessionId, customer }) => {
  const session = await prisma.checkoutSession.findUnique({
    where: { id: sessionId },
    include: {
      orders: {
        select: {
          id: true,
          orderNumber: true,
          totalAmount: true,
          paymentStatus: true,
        },
      },
    },
  });

  if (!session) {
    throw new CheckoutSessionError('Checkout session not found', {
      code: 'CHECKOUT_SESSION_NOT_FOUND',
      status: 404,
    });
  }

  if (session.customerId !== customer.id) {
    throw new CheckoutSessionError('Not authorized for this checkout session', {
      code: 'CHECKOUT_SESSION_NOT_AUTHORIZED',
      status: 403,
    });
  }

  if (['paid', 'successful'].includes(session.paymentStatus)) {
    return {
      alreadyPaid: true,
      session,
      authorizationUrl: null,
      reference: session.paymentReferenceId,
      paymentAmount: 0,
      paymentScope: 'full_group_payment',
    };
  }

  const externalPaymentAmount = roundCurrency(session.totalAmount || 0);
  if (externalPaymentAmount <= 0) {
    throw new CheckoutSessionError('Session does not require external payment', {
      code: 'CHECKOUT_SESSION_NO_EXTERNAL_PAYMENT_REQUIRED',
      status: 400,
    });
  }

  const reference = `CHK-${session.groupOrderNumber}-${Date.now()}`;
  const init = await paystackService.initializeTransaction({
    email: customer.email,
    amount: Math.round(externalPaymentAmount * 100),
    reference,
    metadata: {
      checkoutSessionId: session.id,
      groupOrderNumber: session.groupOrderNumber,
      customerId: customer.id,
      orderIds: session.orders.map((order) => order.id),
      paymentScope: 'full_group_payment',
    },
  });

  await prisma.checkoutSession.update({
    where: { id: session.id },
    data: {
      paymentProvider: 'paystack',
      paymentReferenceId: init.reference || reference,
      paymentStatus: 'processing',
      status: 'processing',
    },
  });

  await prisma.order.updateMany({
    where: {
      checkoutSessionId: session.id,
      paymentStatus: { in: ['pending', 'processing'] },
    },
    data: {
      paymentProvider: 'paystack',
      paymentReferenceId: init.reference || reference,
      paymentStatus: 'processing',
    },
  });

  return {
    alreadyPaid: false,
    session,
    authorizationUrl: init.authorization_url,
    reference: init.reference || reference,
    paymentAmount: externalPaymentAmount,
    paymentScope: 'full_group_payment',
  };
};

const ensureCreditsAppliedForOrder = async ({ order, customerId }) => {
  if (!order || Number(order.creditsApplied || 0) <= 0) return;

  const activeHold = await creditService.getActiveHoldForOrder(customerId, order.id);
  if (activeHold) {
    await creditService.applyCreditsToOrder(customerId, order.id, Number(order.creditsApplied));
    await creditService.captureHold(customerId, order.id);
    return;
  }

  const existingCredit = await prisma.userCredit.findFirst({
    where: {
      userId: customerId,
      orderId: order.id,
      type: 'order_payment',
      isActive: true,
    },
    select: { id: true },
  });

  if (!existingCredit) {
    await creditService.applyCreditsToOrder(customerId, order.id, Number(order.creditsApplied));
  }
};

const confirmCheckoutSessionPayment = async ({ sessionId, customer, reference, provider = 'paystack' }) => {
  const session = await prisma.checkoutSession.findUnique({
    where: { id: sessionId },
    include: {
      orders: {
        select: {
          id: true,
          orderNumber: true,
          paymentStatus: true,
          paymentMethod: true,
          fulfillmentMode: true,
          riderId: true,
          status: true,
          totalAmount: true,
          creditsApplied: true,
          customerId: true,
          groupId: true,
          checkoutSessionId: true,
          groupOrderNumber: true,
        },
      },
    },
  });

  if (!session) {
    throw new CheckoutSessionError('Checkout session not found', {
      code: 'CHECKOUT_SESSION_NOT_FOUND',
      status: 404,
    });
  }

  if (session.customerId !== customer.id) {
    throw new CheckoutSessionError('Not authorized for this checkout session', {
      code: 'CHECKOUT_SESSION_NOT_AUTHORIZED',
      status: 403,
    });
  }

  if (['paid', 'successful'].includes(session.paymentStatus)) {
    let alreadyPaidOrders = session.orders;
    const promotableOrderIds = alreadyPaidOrders
      .filter(
        (order) =>
          order.fulfillmentMode === 'delivery' &&
          order.status === 'pending' &&
          ['paid', 'successful'].includes(order.paymentStatus) &&
          featureFlags.isConfirmedPredispatchEnabled
      )
      .map((order) => order.id);

    if (promotableOrderIds.length > 0) {
      await prisma.order.updateMany({
        where: { id: { in: promotableOrderIds } },
        data: { status: 'confirmed' },
      });
      const promotedOrderIds = new Set(promotableOrderIds);
      alreadyPaidOrders = alreadyPaidOrders.map((order) =>
        promotedOrderIds.has(order.id) ? { ...order, status: 'confirmed' } : order
      );
    }

    for (const updatedOrder of alreadyPaidOrders) {
      if (
        updatedOrder.fulfillmentMode !== 'pickup' &&
        !updatedOrder.riderId &&
        ['paid', 'successful'].includes(updatedOrder.paymentStatus) &&
        isDispatchableStatus(updatedOrder.status)
      ) {
        dispatchService
          .dispatchOrder(updatedOrder.id)
          .then((result) => {
            if (result.success) {
              console.log(`✅ [CheckoutSession] Dispatch initiated for already-paid ${updatedOrder.orderNumber}`);
            } else {
              console.log(`⚠️ [CheckoutSession] Dispatch deferred for already-paid ${updatedOrder.orderNumber}: ${result.error}`);
            }
          })
          .catch((error) => {
            console.error(
              `❌ [CheckoutSession] Dispatch failed for already-paid ${updatedOrder.orderNumber}:`,
              error.message
            );
          });
      }
    }

    return {
      alreadyPaid: true,
      session,
      childOrders: alreadyPaidOrders,
      paymentScope: 'full_group_payment',
      externalPaymentAmount: roundCurrency(session.totalAmount || 0),
    };
  }

  const paymentReference = reference || session.paymentReferenceId || null;
  const externalPaymentAmount = roundCurrency(session.totalAmount || 0);
  const requiresExternalPayment = externalPaymentAmount > 0;

  if (
    reference &&
    reference !== 'credits-only' &&
    session.paymentReferenceId &&
    session.paymentReferenceId !== reference
  ) {
    throw new CheckoutSessionError('Payment reference mismatch for this checkout session', {
      code: 'CHECKOUT_SESSION_REFERENCE_MISMATCH',
      status: 409,
    });
  }

  if (requiresExternalPayment) {
    if (!paymentReference || paymentReference === 'credits-only') {
      throw new CheckoutSessionError('Payment reference is required for this checkout session', {
        code: 'CHECKOUT_SESSION_PAYMENT_REFERENCE_REQUIRED',
        status: 400,
      });
    }

    const verification = await paystackService.verifyTransaction(paymentReference);
    if (verification?.status !== 'success') {
      throw new CheckoutSessionError('Payment not verified', {
        code: 'CHECKOUT_SESSION_PAYMENT_NOT_VERIFIED',
        status: 400,
        meta: { status: verification?.status },
      });
    }

    const verifiedReference = verification?.reference?.toString();
    if (verifiedReference && verifiedReference !== paymentReference) {
      throw new CheckoutSessionError('Verified payment reference mismatch', {
        code: 'CHECKOUT_SESSION_VERIFIED_REFERENCE_MISMATCH',
        status: 409,
      });
    }

    const expectedAmount = Math.round(externalPaymentAmount * 100);
    const verifiedAmount = Number(verification?.amount ?? verification?.amount_in_kobo ?? Number.NaN);
    if (expectedAmount > 0 && Number.isFinite(verifiedAmount) && verifiedAmount !== expectedAmount) {
      throw new CheckoutSessionError('Verified payment amount mismatch', {
        code: 'CHECKOUT_SESSION_VERIFIED_AMOUNT_MISMATCH',
        status: 409,
        meta: { expectedAmount, verifiedAmount },
      });
    }

    const metadataSessionId =
      verification?.metadata?.checkoutSessionId?.toString() ||
      verification?.metadata?.checkout_session_id?.toString() ||
      null;

    if (metadataSessionId && metadataSessionId !== session.id) {
      throw new CheckoutSessionError('Verified payment metadata mismatch', {
        code: 'CHECKOUT_SESSION_METADATA_MISMATCH',
        status: 409,
      });
    }
  }

  const persistedReference =
    paymentReference && paymentReference !== 'credits-only' ? paymentReference : undefined;

  for (const order of session.orders) {
    await ensureCreditsAppliedForOrder({ order, customerId: customer.id });
  }

  const paymentProvider = provider || 'paystack';
  const now = new Date();
  const { updatedOrders, updatedSession } = await prisma.$transaction(async (tx) => {
    const nextOrders = [];

    for (const order of session.orders) {
      const shouldConfirmDeliveryAfterPayment =
        featureFlags.isConfirmedPredispatchEnabled &&
        order.fulfillmentMode === 'delivery' &&
        order.status === 'pending';

      const updatedOrder = await tx.order.update({
        where: { id: order.id },
        data: {
          paymentStatus: 'paid',
          paymentProvider,
          paymentReferenceId: persistedReference,
          ...(shouldConfirmDeliveryAfterPayment ? { status: 'confirmed' } : {}),
        },
        select: {
          id: true,
          orderNumber: true,
          status: true,
          paymentStatus: true,
          paymentMethod: true,
          fulfillmentMode: true,
          riderId: true,
          totalAmount: true,
          checkoutSessionId: true,
          groupId: true,
          groupOrderNumber: true,
        },
      });

      const internalReference = `${persistedReference || 'credits-only'}-${order.id}`;
      const existingPayment = await tx.payment.findUnique({
        where: { referenceId: internalReference },
        select: { id: true },
      });

      if (!existingPayment) {
        await tx.payment.create({
          data: {
            orderId: order.id,
            customerId: customer.id,
            paymentMethod: 'card',
            provider: paymentProvider,
            amount: roundCurrency(order.totalAmount || 0),
            status: 'paid',
            referenceId: internalReference,
            externalReferenceId: persistedReference || null,
            metadata: {
              checkoutSessionId: session.id,
              groupId: session.id,
              groupOrderNumber: session.groupOrderNumber,
              paymentScope: 'full_group_payment',
            },
            completedAt: now,
          },
        });
      }

      await createOrderAudit({
        tx,
        orderId: order.id,
        actorId: customer.id,
        actorRole: customer.role,
        action: 'grouped_payment_confirmed',
        metadata: {
          checkoutSessionId: session.id,
          groupOrderNumber: session.groupOrderNumber,
          reference: persistedReference || null,
          provider: paymentProvider,
          paymentScope: 'full_group_payment',
        },
      });

      nextOrders.push(updatedOrder);
    }

    const nextSession = await tx.checkoutSession.update({
      where: { id: session.id },
      data: {
        paymentStatus: 'paid',
        status: 'paid',
        paymentProvider,
        paymentReferenceId: persistedReference,
        paidAt: now,
      },
      select: {
        id: true,
        groupOrderNumber: true,
        paymentStatus: true,
        status: true,
        totalAmount: true,
        creditsApplied: true,
        paymentReferenceId: true,
      },
    });

    return { updatedOrders: nextOrders, updatedSession: nextSession };
  });

  for (const updatedOrder of updatedOrders) {
    if (
      updatedOrder.fulfillmentMode !== 'pickup' &&
      !updatedOrder.riderId &&
      ['paid', 'successful'].includes(updatedOrder.paymentStatus) &&
      isDispatchableStatus(updatedOrder.status)
    ) {
      dispatchService
        .dispatchOrder(updatedOrder.id)
        .then((result) => {
          if (result.success) {
            console.log(`✅ [CheckoutSession] Dispatch initiated for ${updatedOrder.orderNumber}`);
          } else {
            console.log(`⚠️ [CheckoutSession] Dispatch deferred for ${updatedOrder.orderNumber}: ${result.error}`);
          }
        })
        .catch((error) => {
          console.error(
            `❌ [CheckoutSession] Dispatch failed for ${updatedOrder.orderNumber}:`,
            error.message
          );
        });
    }
  }

  return {
    alreadyPaid: false,
    session: updatedSession,
    childOrders: updatedOrders,
    paymentScope: 'full_group_payment',
    externalPaymentAmount,
  };
};

const releaseCheckoutSessionCreditHolds = async ({ sessionId, customer }) => {
  const session = await prisma.checkoutSession.findUnique({
    where: { id: sessionId },
    include: {
      orders: {
        select: { id: true },
      },
    },
  });

  if (!session) {
    throw new CheckoutSessionError('Checkout session not found', {
      code: 'CHECKOUT_SESSION_NOT_FOUND',
      status: 404,
    });
  }

  if (session.customerId !== customer.id) {
    throw new CheckoutSessionError('Not authorized for this checkout session', {
      code: 'CHECKOUT_SESSION_NOT_AUTHORIZED',
      status: 403,
    });
  }

  await Promise.all(
    (session.orders || []).map((order) => creditService.releaseHold(customer.id, order.id).catch(() => null))
  );

  return {
    sessionId: session.id,
    releasedOrderCount: (session.orders || []).length,
  };
};

module.exports = {
  CheckoutSessionError,
  createCheckoutSession,
  initializeCheckoutSessionPayment,
  confirmCheckoutSessionPayment,
  releaseCheckoutSessionCreditHolds,
};
