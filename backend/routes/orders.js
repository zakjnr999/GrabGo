const express = require("express");
const { body, validationResult } = require("express-validator");
const crypto = require("crypto");
const prisma = require("../config/prisma");
const { protect, authorize } = require("../middleware/auth");
const { uploadSingle, uploadToCloudinary } = require("../middleware/upload");
const { cacheMiddleware } = require("../middleware/cache");
const cache = require("../utils/cache");
const { sendOrderNotification, sendToUser } = require("../services/fcm_service");
const { createNotification } = require("../services/notification_service");
const ReferralService = require("../services/referral_service");
const creditService = require("../services/credit_service");
const { calculateOrderPricing } = require("../services/pricing_service");
const paystackService = require("../services/paystack_service");
const { getIO } = require("../utils/socket");
const dispatchService = require("../services/dispatch_service");
const featureFlags = require("../config/feature_flags");
const { normalizeGhanaPhone } = require("../services/otp_service");
const {
  DeliveryVerificationError,
  generateDeliveryCode,
  hashDeliveryCode,
  encryptDeliveryCode,
  decryptDeliveryCode,
  getResendAvailability,
  sendDeliveryCodeSms,
  verifyDeliveryCodeOrThrow,
} = require("../services/delivery_verification_service");
const {
  ScheduledOrderError,
  validateScheduledDeliveryRequest,
  normalizeDeliveryTimeType,
} = require("../services/scheduled_order_service");
const {
  createOrderAudit,
  reserveInventoryForOrder,
  releaseInventoryHolds,
  cancelPickupOrder,
} = require("../services/pickup_order_service");

const router = express.Router();

const { FOOD_INCLUDE_RELATIONS, formatFoodResponse } = require('../utils/food_helpers');

const normalizeFulfillmentMode = (mode) => {
  if (!mode) return "delivery";
  return String(mode).trim().toLowerCase() === "pickup" ? "pickup" : "delivery";
};

const PICKUP_OTP_SECRET = process.env.PICKUP_OTP_SECRET || process.env.JWT_SECRET || "grabgo-pickup-otp-secret";
const PICKUP_OTP_MAX_ATTEMPTS = Number(process.env.PICKUP_OTP_MAX_ATTEMPTS || 5);
const PICKUP_OTP_LOCK_SECONDS = Number(process.env.PICKUP_OTP_LOCK_SECONDS || 300);
const PICKUP_ACCEPT_TIMEOUT_MINUTES = Number(process.env.PICKUP_ACCEPT_TIMEOUT_MINUTES || 10);
const PICKUP_READY_EXPIRY_MINUTES = Number(process.env.PICKUP_READY_EXPIRY_MINUTES || 30);
const DELIVERY_ACTIVE_STATUSES = new Set(["picked_up", "on_the_way"]);
const STATUS_UPDATE_ROLE_RULES = {
  customer: new Set(["cancelled"]),
  restaurant: new Set(["confirmed", "preparing", "ready", "cancelled"]),
  rider: new Set(["picked_up", "on_the_way", "delivered", "cancelled"]),
  admin: null,
};
const SENSITIVE_ORDER_FIELDS = new Set(["pickupOtpHash", "deliveryCodeHash", "deliveryCodeEncrypted"]);

const generatePickupCode = () => {
  const value = Math.floor(100000 + Math.random() * 900000);
  return String(value);
};

const hashPickupCode = (orderId, code) => {
  return crypto
    .createHmac("sha256", PICKUP_OTP_SECRET)
    .update(`${orderId}:${code}`)
    .digest("hex");
};

const isPickupOtpLocked = (order) => {
  if (!order?.pickupOtpLastAttemptAt || !order?.pickupOtpFailedAttempts) return false;
  if (order.pickupOtpFailedAttempts < PICKUP_OTP_MAX_ATTEMPTS) return false;

  const lockUntil = new Date(order.pickupOtpLastAttemptAt).getTime() + PICKUP_OTP_LOCK_SECONDS * 1000;
  return Date.now() < lockUntil;
};

const sanitizeOrderPayload = (payload) => {
  if (Array.isArray(payload)) {
    return payload.map((entry) => sanitizeOrderPayload(entry));
  }
  if (!payload || typeof payload !== "object") {
    return payload;
  }

  const sanitized = { ...payload };
  for (const field of SENSITIVE_ORDER_FIELDS) {
    delete sanitized[field];
  }
  return sanitized;
};

const getVendorContextForUser = async (user) => {
  if (!user?.email) return null;
  const [restaurant, groceryStore, pharmacyStore, grabMartStore] = await Promise.all([
    prisma.restaurant.findFirst({
      where: { email: user.email },
      select: { id: true },
    }),
    prisma.groceryStore.findFirst({
      where: { email: user.email },
      select: { id: true },
    }),
    prisma.pharmacyStore.findFirst({
      where: { email: user.email },
      select: { id: true },
    }),
    prisma.grabMartStore.findFirst({
      where: { email: user.email },
      select: { id: true },
    }),
  ]);

  return {
    restaurantId: restaurant?.id || null,
    groceryStoreId: groceryStore?.id || null,
    pharmacyStoreId: pharmacyStore?.id || null,
    grabMartStoreId: grabMartStore?.id || null,
  };
};

const isOrderOwnedByVendorContext = (order, vendorContext) =>
  Boolean(
    (vendorContext?.restaurantId && order?.restaurantId === vendorContext.restaurantId) ||
      (vendorContext?.groceryStoreId && order?.groceryStoreId === vendorContext.groceryStoreId) ||
      (vendorContext?.pharmacyStoreId && order?.pharmacyStoreId === vendorContext.pharmacyStoreId) ||
      (vendorContext?.grabMartStoreId && order?.grabMartStoreId === vendorContext.grabMartStoreId)
  );

const normalizeGiftRecipientPhone = (phoneNumber) => {
  if (!phoneNumber) return null;
  const normalized = normalizeGhanaPhone(phoneNumber);
  return normalized ? normalized.e164 : null;
};

/**
 * Helper to send order status notification to customer
 */
const notifyOrderStatusChange = async (order, status, customMessage = null, io = null) => {
  try {
    if (!order.customerId && !order.customer) return;

    const customerId = order.customerId || order.customer.id;
    const orderNumber = order.orderNumber;
    const orderId = order.id;

    // 1. Send FCM push notification
    await sendOrderNotification(
      customerId,
      orderId,
      orderNumber,
      status,
      customMessage
    );

    // 2. Create in-app notification with WebSocket delivery
    const statusMessages = {
      confirmed: 'Your order has been confirmed!',
      preparing: 'Your order is being prepared.',
      ready: 'Your order is ready for pickup!',
      picked_up: 'Your order has been picked up.',
      on_the_way: 'Your order is on the way!',
      delivered: 'Your order has been delivered. Enjoy!',
      cancelled: 'Your order has been cancelled.',
    };

    const statusEmojis = {
      confirmed: '✅',
      preparing: '🍳',
      ready: '📦',
      picked_up: '🚴',
      on_the_way: '🛣️',
      delivered: '✅',
      cancelled: '❌',
    };

    const emoji = statusEmojis[status] || '📦';
    const message = customMessage || statusMessages[status] || `Order status: ${status}`;

    const ioInstance = io || getIO();
    if (ioInstance) {
      await createNotification(
        customerId,
        'order',
        `${emoji} Order #${orderNumber}`,
        message,
        {
          orderId,
          orderNumber,
          status,
          route: `/orders/${orderId}`
        },
        ioInstance
      );
    }
  } catch (error) {
    console.error('Error sending order notification:', error.message);
  }
};

/**
 * Helper to send notification to rider when assigned
 */
const notifyRiderAssignment = async (riderId, order) => {
  try {
    await sendToUser(
      riderId,
      {
        title: '🚴 New Delivery Assignment',
        body: `Order #${order.orderNumber} has been assigned to you. Tap to view details.`,
      },
      {
        type: 'rider_assignment',
        orderId: order.id,
        orderNumber: order.orderNumber,
      }
    );
  } catch (error) {
    console.error('Error sending rider assignment notification:', error.message);
  }
};

/**
 * Helper to generate unique order number
 */
const generateOrderNumber = async () => {
  const timestamp = Date.now();
  const random = Math.floor(Math.random() * 10000);
  let orderNumber = `ORD-${timestamp}-${random}`;

  let exists = await prisma.order.findUnique({ where: { orderNumber } });
  let attempts = 0;
  while (exists && attempts < 5) {
    const newRandom = Math.floor(Math.random() * 10000);
    orderNumber = `ORD-${timestamp}-${newRandom}`;
    exists = await prisma.order.findUnique({ where: { orderNumber } });
    attempts++;
  }
  return orderNumber;
};

router.post(
  "/",
  protect,
  [
    body("restaurant").optional().isString().withMessage("restaurant must be a string"),
    body("fulfillmentMode").optional().isIn(["delivery", "pickup"]).withMessage("Invalid fulfillment mode"),
    body("deliveryTimeType").optional().isIn(["asap", "scheduled"]).withMessage("Invalid delivery time type"),
    body("scheduledForAt")
      .optional()
      .isISO8601({ strict: true, strictSeparator: true })
      .withMessage("scheduledForAt must be a valid ISO datetime"),
    body("items")
      .isArray({ min: 1 })
      .withMessage("At least one item is required"),
    body("deliveryAddress").optional(),
    body("pickupContactName").optional().isString().withMessage("pickupContactName must be a string"),
    body("pickupContactPhone").optional().isString().withMessage("pickupContactPhone must be a string"),
    body("acceptNoShowPolicy").optional().isBoolean().withMessage("acceptNoShowPolicy must be a boolean"),
    body("isGiftOrder").optional().isBoolean().withMessage("isGiftOrder must be a boolean"),
    body("giftRecipientName").optional().isString().withMessage("giftRecipientName must be a string"),
    body("giftRecipientPhone").optional().isString().withMessage("giftRecipientPhone must be a string"),
    body("giftNote").optional().isString().withMessage("giftNote must be a string"),
    body("paymentMethod")
      .isIn(["card"])
      .withMessage("Invalid payment method"),
    body("useCredits").optional({ nullable: true }).isBoolean().withMessage("useCredits must be a boolean"),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      if (req.user.role !== "customer") {
        return res.status(403).json({
          success: false,
          message: "Only customers can place orders",
        });
      }

      const {
        restaurant: requestedVendorId,
        items,
        deliveryAddress,
        fulfillmentMode: rawFulfillmentMode,
        deliveryTimeType,
        scheduledForAt,
        pickupContactName,
        pickupContactPhone,
        acceptNoShowPolicy,
        isGiftOrder,
        giftRecipientName,
        giftRecipientPhone,
        giftNote,
        paymentMethod,
        useCredits,
        notes,
        noShowPolicyVersion,
        orderNumber: bodyOrderNumber
      } = req.body;

      const fulfillmentMode = normalizeFulfillmentMode(rawFulfillmentMode);
      const isPickupMode = fulfillmentMode === "pickup";
      const isDeliveryMode = !isPickupMode;
      const isGiftOrderRequested = isGiftOrder === true;
      const normalizedGiftRecipientName = giftRecipientName ? String(giftRecipientName).trim() : null;
      const normalizedGiftNote = giftNote ? String(giftNote).trim() : null;
      const normalizedGiftPhone = normalizeGiftRecipientPhone(giftRecipientPhone);

      if (isPickupMode && !featureFlags.isPickupCheckoutEnabled) {
        return res.status(403).json({
          success: false,
          message: "Pickup ordering is temporarily unavailable",
        });
      }

      if (isDeliveryMode && !deliveryAddress) {
        return res.status(400).json({
          success: false,
          message: "Delivery address is required for delivery orders",
        });
      }

      if (isPickupMode) {
        if (!pickupContactName || !pickupContactPhone) {
          return res.status(400).json({
            success: false,
            message: "Pickup contact name and phone are required",
          });
        }
        if (acceptNoShowPolicy !== true) {
          return res.status(400).json({
            success: false,
            message: "You must accept the no-show pickup policy",
          });
        }
      }

      if (isGiftOrderRequested) {
        if (!featureFlags.isGiftOrdersEnabled) {
          return res.status(403).json({
            success: false,
            message: "Gift orders are temporarily unavailable",
          });
        }

        if (!isDeliveryMode) {
          return res.status(400).json({
            success: false,
            message: "Gift orders are only supported for delivery orders",
          });
        }

        if (!normalizedGiftRecipientName) {
          return res.status(400).json({
            success: false,
            message: "Recipient name is required for gift orders",
          });
        }

        if (giftRecipientPhone && !normalizedGiftPhone) {
          return res.status(400).json({
            success: false,
            message: "Invalid gift recipient phone number",
          });
        }
      }

      const normalizedDeliveryTimeType = normalizeDeliveryTimeType(deliveryTimeType);
      let scheduledOrderMetadata = null;
      try {
        scheduledOrderMetadata = validateScheduledDeliveryRequest({
          deliveryTimeType: normalizedDeliveryTimeType,
          scheduledForAt,
          fulfillmentMode,
          featureEnabled: featureFlags.isScheduledOrdersEnabled,
          now: new Date(),
        });
      } catch (scheduleError) {
        if (scheduleError instanceof ScheduledOrderError) {
          return res.status(scheduleError.status || 400).json({
            success: false,
            message: scheduleError.message,
            code: scheduleError.code || "SCHEDULED_ORDER_ERROR",
            ...(scheduleError.meta || {}),
          });
        }
        throw scheduleError;
      }

      const isScheduledOrderRequested = scheduledOrderMetadata?.isScheduledOrder === true;
      const scheduledForAtDate = scheduledOrderMetadata?.scheduledForAt || null;
      const scheduledWindowStartAt = scheduledOrderMetadata?.scheduledWindowStartAt || null;
      const scheduledWindowEndAt = scheduledOrderMetadata?.scheduledWindowEndAt || null;
      const scheduledReleaseAt = scheduledOrderMetadata?.scheduledReleaseAt || null;

      const normalizeItemType = (itemType) => {
        if (!itemType) return null;
        const normalized = String(itemType).toLowerCase();
        if (normalized === "food") return "Food";
        if (normalized === "groceryitem" || normalized === "grocery") return "GroceryItem";
        if (normalized === "pharmacyitem" || normalized === "pharmacy") return "PharmacyItem";
        if (normalized === "grabmartitem" || normalized === "grabmart" || normalized === "convenience") return "GrabMartItem";
        return null;
      };

      const itemIdFromPayload = (item) => (
        item.food || item.groceryItem || item.pharmacyItem || item.grabMartItem || item.itemId || item.id
      );

      const orderNumber = bodyOrderNumber || await generateOrderNumber();

      let subtotal = 0;
      let maxItemPrepMinutes = 0;
      const orderItemsData = [];
      let resolvedOrderType = null;
      let resolvedVendorId = null;

      for (const item of items) {
        const payloadItemId = itemIdFromPayload(item);
        const payloadType = normalizeItemType(item.itemType);
        const quantity = Number(item.quantity) || 1;

        if (!payloadItemId) {
          return res.status(400).json({
            success: false,
            message: "Each order item must include a valid item id",
          });
        }

        if (quantity < 1) {
          return res.status(400).json({
            success: false,
            message: `Invalid quantity for item ${payloadItemId}`,
          });
        }

        const lookupOrder = payloadType
          ? [payloadType]
          : ["Food", "GroceryItem", "PharmacyItem", "GrabMartItem"];

        let matchedItem = null;

        for (const type of lookupOrder) {
          if (type === "Food") {
            const food = await prisma.food.findUnique({ where: { id: payloadItemId } });
            if (food) {
              matchedItem = {
                itemType: "Food",
                orderType: "food",
                vendorId: food.restaurantId,
                price: food.price,
                name: food.name,
                image: food.foodImage,
                prepTimeMinutes: food.prepTimeMinutes,
                idField: "foodId",
                idValue: food.id,
              };
              break;
            }
          } else if (type === "GroceryItem") {
            const groceryItem = await prisma.groceryItem.findUnique({ where: { id: payloadItemId } });
            if (groceryItem) {
              matchedItem = {
                itemType: "GroceryItem",
                orderType: "grocery",
                vendorId: groceryItem.storeId,
                price: groceryItem.price,
                name: groceryItem.name,
                image: groceryItem.image,
                prepTimeMinutes: groceryItem.prepTimeMinutes,
                idField: "groceryItemId",
                idValue: groceryItem.id,
              };
              break;
            }
          } else if (type === "PharmacyItem") {
            const pharmacyItem = await prisma.pharmacyItem.findUnique({ where: { id: payloadItemId } });
            if (pharmacyItem) {
              matchedItem = {
                itemType: "PharmacyItem",
                orderType: "pharmacy",
                vendorId: pharmacyItem.storeId,
                price: pharmacyItem.price,
                name: pharmacyItem.name,
                image: pharmacyItem.image,
                prepTimeMinutes: pharmacyItem.prepTimeMinutes,
                idField: "pharmacyItemId",
                idValue: pharmacyItem.id,
              };
              break;
            }
          } else if (type === "GrabMartItem") {
            const grabMartItem = await prisma.grabMartItem.findUnique({ where: { id: payloadItemId } });
            if (grabMartItem) {
              matchedItem = {
                itemType: "GrabMartItem",
                orderType: "grabmart",
                vendorId: grabMartItem.storeId,
                price: grabMartItem.price,
                name: grabMartItem.name,
                image: grabMartItem.image,
                prepTimeMinutes: 0,
                idField: "grabMartItemId",
                idValue: grabMartItem.id,
              };
              break;
            }
          }
        }

        if (!matchedItem) {
          return res.status(404).json({
            success: false,
            message: `Item ${payloadItemId} not found`,
          });
        }

        if (resolvedOrderType && resolvedOrderType !== matchedItem.orderType) {
          return res.status(400).json({
            success: false,
            message: "Orders can only contain items from one service type",
          });
        }

        if (resolvedVendorId && resolvedVendorId !== matchedItem.vendorId) {
          return res.status(400).json({
            success: false,
            message: "Orders can only contain items from one store/restaurant",
          });
        }

        resolvedOrderType = matchedItem.orderType;
        resolvedVendorId = matchedItem.vendorId;

        const itemTotal = matchedItem.price * quantity;
        subtotal += itemTotal;
        if (Number.isFinite(matchedItem.prepTimeMinutes) && matchedItem.prepTimeMinutes > maxItemPrepMinutes) {
          maxItemPrepMinutes = matchedItem.prepTimeMinutes;
        }

        const orderItemData = {
          itemType: matchedItem.itemType,
          name: matchedItem.name,
          quantity,
          price: matchedItem.price,
          image: matchedItem.image,
        };
        orderItemData[matchedItem.idField] = matchedItem.idValue;
        orderItemsData.push(orderItemData);
      }

      if (!resolvedOrderType || !resolvedVendorId) {
        return res.status(400).json({
          success: false,
          message: "Unable to determine order service/store",
        });
      }

      if (requestedVendorId && requestedVendorId !== resolvedVendorId) {
        return res.status(400).json({
          success: false,
          message: "Provided vendor does not match item store/restaurant",
        });
      }

      let vendorDoc = null;
      if (resolvedOrderType === "food") {
        vendorDoc = await prisma.restaurant.findUnique({ where: { id: resolvedVendorId } });
      } else if (resolvedOrderType === "grocery") {
        vendorDoc = await prisma.groceryStore.findUnique({ where: { id: resolvedVendorId } });
      } else if (resolvedOrderType === "pharmacy") {
        vendorDoc = await prisma.pharmacyStore.findUnique({ where: { id: resolvedVendorId } });
      } else if (resolvedOrderType === "grabmart") {
        vendorDoc = await prisma.grabMartStore.findUnique({ where: { id: resolvedVendorId } });
      }

      if (!vendorDoc || vendorDoc.status !== "approved") {
        return res.status(404).json({
          success: false,
          message: "Store/restaurant not found or inactive",
        });
      }

      const baseDeliveryFee = vendorDoc.deliveryFee || 0;
      const pricing = await calculateOrderPricing({
        subtotal,
        baseDeliveryFee: isPickupMode ? 0 : baseDeliveryFee,
        userId: req.user.id,
        deliveryLocation: {
          latitude: deliveryAddress?.latitude,
          longitude: deliveryAddress?.longitude
        },
        vendorLocation: {
          latitude: vendorDoc.latitude,
          longitude: vendorDoc.longitude
        },
        vendorPrepTime: maxItemPrepMinutes > 0 ? maxItemPrepMinutes : (vendorDoc.averagePreparationTime || 15),
        vendorDeliveryTime: vendorDoc.averageDeliveryTime || 30,
        fulfillmentMode,
      });
      const tax = pricing.tax;
      let totalAmount = pricing.total;

      const shouldUseCredits = useCredits !== false;
      // Apply credits if available
      const creditResult = await creditService.calculateCreditApplication(req.user.id, totalAmount, shouldUseCredits);
      const creditApplied = creditResult?.creditsApplied || 0;
      if (creditApplied > 0) {
        totalAmount = creditResult.remainingPayment;
      }
      const isCreditOnly = creditApplied > 0 && totalAmount <= 0;

      const orderData = {
        orderNumber,
        orderType: resolvedOrderType,
        fulfillmentMode,
        customerId: req.user.id,
        subtotal: pricing.subtotal,
        deliveryFee: pricing.deliveryFee,
        rainFee: pricing.rainFee,
        tax,
        totalAmount,
        creditsApplied: creditApplied,
        deliveryStreet: isDeliveryMode ? (deliveryAddress?.street || deliveryAddress) : null,
        deliveryCity: isDeliveryMode ? (deliveryAddress?.city || 'Unknown') : null,
        deliveryState: isDeliveryMode ? deliveryAddress?.state : null,
        deliveryZipCode: isDeliveryMode ? deliveryAddress?.zipCode : null,
        deliveryLatitude: isDeliveryMode ? deliveryAddress?.latitude : null,
        deliveryLongitude: isDeliveryMode ? deliveryAddress?.longitude : null,
        pickupContactName: isPickupMode ? pickupContactName : null,
        pickupContactPhone: isPickupMode ? pickupContactPhone : null,
        isGiftOrder: isGiftOrderRequested,
        giftRecipientName: isGiftOrderRequested ? normalizedGiftRecipientName : null,
        giftRecipientPhone: isGiftOrderRequested ? normalizedGiftPhone : null,
        giftNote: isGiftOrderRequested ? (normalizedGiftNote || null) : null,
        isScheduledOrder: isScheduledOrderRequested,
        scheduledForAt: isScheduledOrderRequested ? scheduledForAtDate : null,
        scheduledWindowStartAt: isScheduledOrderRequested ? scheduledWindowStartAt : null,
        scheduledWindowEndAt: isScheduledOrderRequested ? scheduledWindowEndAt : null,
        scheduledReleaseAt: isScheduledOrderRequested ? scheduledReleaseAt : null,
        scheduledReleasedAt: null,
        deliveryVerificationRequired: isGiftOrderRequested,
        deliveryCodeFailedAttempts: 0,
        deliveryCodeResendCount: 0,
        noShowPolicyAcceptedAt: isPickupMode && acceptNoShowPolicy ? new Date() : null,
        noShowPolicyVersion: isPickupMode && acceptNoShowPolicy ? (noShowPolicyVersion || "v1") : null,
        paymentMethod,
        notes,
        status: isCreditOnly && !isScheduledOrderRequested ? "confirmed" : "pending",
        items: {
          create: orderItemsData
        }
      };

      if (isPickupMode && isCreditOnly) {
        orderData.acceptByAt = new Date(Date.now() + PICKUP_ACCEPT_TIMEOUT_MINUTES * 60 * 1000);
      }

      if (resolvedOrderType === "food") orderData.restaurantId = resolvedVendorId;
      if (resolvedOrderType === "grocery") orderData.groceryStoreId = resolvedVendorId;
      if (resolvedOrderType === "pharmacy") orderData.pharmacyStoreId = resolvedVendorId;
      if (resolvedOrderType === "grabmart") orderData.grabMartStoreId = resolvedVendorId;

      if (isCreditOnly) {
        orderData.paymentStatus = "paid";
      }

      // Create order with Prisma transaction to handle nested items
      const order = await prisma.order.create({
        data: orderData,
        include: {
          items: {
            include: { food: true, groceryItem: true, pharmacyItem: true, grabMartItem: true }
          },
          restaurant: {
            select: {
              restaurantName: true,
              logo: true,
              phone: true,
              address: true,
              city: true,
              area: true,
              latitude: true,
              longitude: true
            }
          },
          groceryStore: {
            select: {
              storeName: true,
              logo: true,
              phone: true,
              address: true,
              city: true,
              area: true,
              latitude: true,
              longitude: true
            }
          },
          pharmacyStore: {
            select: {
              storeName: true,
              logo: true,
              phone: true,
              address: true,
              city: true,
              area: true,
              latitude: true,
              longitude: true
            }
          },
          grabMartStore: {
            select: {
              storeName: true,
              logo: true,
              phone: true,
              address: true,
              city: true,
              area: true,
              latitude: true,
              longitude: true
            }
          },
          customer: {
            select: {
              username: true,
              email: true,
              phone: true
            }
          }
        }
      });

      let giftDeliveryCode = null;
      if (isGiftOrderRequested) {
        giftDeliveryCode = generateDeliveryCode();
        const sentAt = new Date();
        await prisma.order.update({
          where: { id: order.id },
          data: {
            deliveryCodeHash: hashDeliveryCode(order.id, giftDeliveryCode),
            deliveryCodeEncrypted: encryptDeliveryCode(giftDeliveryCode),
            deliveryCodeFailedAttempts: 0,
            deliveryCodeLockedUntil: null,
            deliveryCodeResendCount: 0,
            deliveryCodeLastSentAt: sentAt,
          },
        });

        await createOrderAudit({
          orderId: order.id,
          actorId: req.user.id,
          actorRole: req.user.role,
          action: "gift_code_generated",
          metadata: {
            sentAt: sentAt.toISOString(),
          },
        }).catch(() => null);
      }

      if (isPickupMode && isCreditOnly) {
        try {
          await reserveInventoryForOrder({ orderId: order.id });
        } catch (inventoryError) {
          await prisma.order.update({
            where: { id: order.id },
            data: {
              status: "cancelled",
              cancelledDate: new Date(),
              cancellationReason: inventoryError.message || "Unable to reserve inventory for pickup order",
              paymentStatus: "refunded",
              updatedAt: new Date(),
            },
          });

          return res.status(400).json({
            success: false,
            message: inventoryError.message || "Unable to place pickup order due to stock changes",
          });
        }
      }

      // Deduct credits only for credit-only orders (no external payment)
      if (isCreditOnly && creditApplied > 0) {
        await creditService.applyCreditsToOrder(req.user.id, order.id, creditApplied);
      }

      // Hold credits for pending card payments
      if (!isCreditOnly && shouldUseCredits && creditApplied > 0) {
        await creditService.createHold({
          userId: req.user.id,
          orderId: order.id,
          amount: creditApplied
        });
      }

      // Check if this is user's first order and complete referral
      const userOrderCount = await prisma.order.count({
        where: { customerId: req.user.id }
      });

      if (userOrderCount === 1) {
        const io = getIO();
        const referralResult = await ReferralService.completeReferral(
          req.user.id,
          order.id,
          pricing.total, // Use original amount before credits
          io
        );

        if (referralResult.success) {
          console.log(`Referral completed for user ${req.user.id}`);
        }
      }

      // Update user's lastOrderDate for meal nudge targeting
      await prisma.user.update({
        where: { id: req.user.id },
        data: { lastOrderDate: new Date() }
      });

      if (isScheduledOrderRequested) {
        await createOrderAudit({
          orderId: order.id,
          actorId: req.user.id,
          actorRole: req.user.role,
          action: "scheduled_order_created",
          metadata: {
            scheduledForAt: scheduledForAtDate ? scheduledForAtDate.toISOString() : null,
            scheduledReleaseAt: scheduledReleaseAt ? scheduledReleaseAt.toISOString() : null,
            deliveryTimeType: normalizedDeliveryTimeType,
          },
        }).catch(() => null);
      }

      if (isGiftOrderRequested && giftDeliveryCode) {
        if (req.user.phone) {
          const customerSendResult = await sendDeliveryCodeSms({
            phoneNumber: req.user.phone,
            orderNumber: order.orderNumber,
            code: giftDeliveryCode,
            audience: "customer",
          });

          await createOrderAudit({
            orderId: order.id,
            actorId: req.user.id,
            actorRole: req.user.role,
            action: "gift_code_sent_customer",
            metadata: {
              success: !!customerSendResult?.success,
              provider: customerSendResult?.provider || null,
              errorMessage: customerSendResult?.success ? null : (customerSendResult?.message || null),
            },
          }).catch(() => null);
        }

        if (normalizedGiftPhone && !isScheduledOrderRequested) {
          const recipientSendResult = await sendDeliveryCodeSms({
            phoneNumber: normalizedGiftPhone,
            orderNumber: order.orderNumber,
            code: giftDeliveryCode,
            audience: "recipient",
            recipientName: normalizedGiftRecipientName,
          });

          await createOrderAudit({
            orderId: order.id,
            actorId: req.user.id,
            actorRole: req.user.role,
            action: "gift_code_sent_recipient",
            metadata: {
              success: !!recipientSendResult?.success,
              provider: recipientSendResult?.provider || null,
              errorMessage: recipientSendResult?.success ? null : (recipientSendResult?.message || null),
            },
          }).catch(() => null);
        }
      }

      const responseOrder = sanitizeOrderPayload(order);
      if (isGiftOrderRequested && giftDeliveryCode) {
        responseOrder.giftDeliveryCode = giftDeliveryCode;
      }

      res.status(201).json({
        success: true,
        message: "Order created successfully",
        data: responseOrder,
      });
    } catch (error) {
      if (error instanceof ScheduledOrderError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          code: error.code || "SCHEDULED_ORDER_ERROR",
          ...(error.meta || {}),
        });
      }

      console.error("Create order error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.get("/", protect, async (req, res) => {
  try {
    let where = {};

    if (req.user.role === "customer") {
      where.customerId = req.user.id;
    } else if (req.user.role === "restaurant") {
      const vendorContext = await getVendorContextForUser(req.user);
      const vendorConditions = [
        vendorContext?.restaurantId ? { restaurantId: vendorContext.restaurantId } : null,
        vendorContext?.groceryStoreId ? { groceryStoreId: vendorContext.groceryStoreId } : null,
        vendorContext?.pharmacyStoreId ? { pharmacyStoreId: vendorContext.pharmacyStoreId } : null,
        vendorContext?.grabMartStoreId ? { grabMartStoreId: vendorContext.grabMartStoreId } : null,
      ].filter(Boolean);

      if (vendorConditions.length > 0) {
        where.OR = vendorConditions;
      } else {
        return res.json({
          success: true,
          message: "No orders found",
          data: [],
        });
      }
    } else if (req.user.role === "rider") {
      where.riderId = req.user.id;
    }

    const orders = await prisma.order.findMany({
      where,
      include: {
        customer: { select: { id: true, username: true, email: true, phone: true, profilePicture: true } },
        restaurant: {
          select: {
            restaurantName: true,
            logo: true,
            address: true,
            latitude: true,
            longitude: true,
            isOpen: true,
            isAcceptingOrders: true,
            status: true
          }
        },
        groceryStore: {
          select: {
            storeName: true,
            logo: true,
            address: true,
            latitude: true,
            longitude: true,
            isOpen: true,
            isAcceptingOrders: true,
            status: true
          }
        },
        pharmacyStore: {
          select: {
            storeName: true,
            logo: true,
            address: true,
            latitude: true,
            longitude: true,
            isOpen: true,
            isAcceptingOrders: true,
            status: true
          }
        },
        grabMartStore: {
          select: {
            storeName: true,
            logo: true,
            address: true,
            latitude: true,
            longitude: true,
            isOpen: true,
            isAcceptingOrders: true,
            status: true
          }
        },
        rider: { select: { username: true, email: true, phone: true } },
        items: {
          include: { food: true, groceryItem: true, pharmacyItem: true, grabMartItem: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json({
      success: true,
      message: "Orders retrieved successfully",
      data: sanitizeOrderPayload(orders),
    });
  } catch (error) {
    console.error("Get orders error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

/**
 * Get user's recent order items for "Order Again" section
 */
router.get("/recent-items", protect, cacheMiddleware(cache.CACHE_KEYS.FOOD_ITEM + ':recent', 300, true), async (req, res) => {
  try {
    console.log(`\n🔍 [DEBUG] Fetching recent items for user: ${req.user.id}`);

    // First, check what statuses this user's orders actually have
    const allUserOrders = await prisma.order.findMany({
      where: { customerId: req.user.id },
      select: { status: true, orderType: true, id: true },
      take: 10
    });

    if (allUserOrders.length > 0) {
      const statusBreakdown = {};
      allUserOrders.forEach(o => {
        const key = `${o.orderType}:${o.status}`;
        statusBreakdown[key] = (statusBreakdown[key] || 0) + 1;
      });
      console.log(`📊 [DEBUG] User's order status breakdown:`, statusBreakdown);
    } else {
      console.log(`⚠️ [DEBUG] User has NO orders in database at all`);
    }

    // Get user's recent orders (delivered or on_the_way to show what they like)
    const orders = await prisma.order.findMany({
      where: {
        customerId: req.user.id,
        status: { in: ["delivered", "on_the_way", "picked_up"] }
      },
      include: {
        items: {
          include: {
            food: { include: FOOD_INCLUDE_RELATIONS },
            groceryItem: { include: { store: true, category: true } },
            pharmacyItem: { include: { store: true, category: true } },
            grabMartItem: { include: { store: true, category: true } }
          }
        }
      },
      orderBy: { orderDate: 'desc' },
      take: 30
    });

    console.log(`📦 [DEBUG] Found ${orders.length} orders`);
    if (orders.length > 0) {
      const totalItems = orders.reduce((sum, o) => sum + o.items.length, 0);
      console.log(`📦 [DEBUG] Total order items: ${totalItems}`);

      // Log item type breakdown
      const itemTypes = {};
      orders.forEach(o => {
        o.items.forEach(item => {
          itemTypes[item.itemType] = (itemTypes[item.itemType] || 0) + 1;
        });
      });
      console.log(`📦 [DEBUG] Item types:`, itemTypes);
    }

    const itemsMap = new Map();

    orders.forEach(order => {
      order.items.forEach(item => {
        // Universal unique key based on item type and id
        let itemId, itemData, type;

        if (item.itemType === 'Food' && item.food) {
          itemId = `food_${item.food.id}`;

          // Format food item with dynamic status/delivery time
          const formattedFoodArray = formatFoodResponse([item.food], req.query.userLat, req.query.userLng);
          itemData = formattedFoodArray.length > 0 ? formattedFoodArray[0] : item.food;

          type = 'Food';
        } else if (item.itemType === 'GroceryItem' && item.groceryItem) {
          itemId = `grocery_${item.groceryItem.id}`;
          itemData = item.groceryItem;
          type = 'GroceryItem';
        } else if (item.itemType === 'PharmacyItem' && item.pharmacyItem) {
          itemId = `pharmacy_${item.pharmacyItem.id}`;
          itemData = item.pharmacyItem;
          type = 'PharmacyItem';
        } else if (item.itemType === 'GrabMartItem' && item.grabMartItem) {
          itemId = `grabmart_${item.grabMartItem.id}`;
          itemData = item.grabMartItem;
          type = 'GrabMartItem';
        }

        if (!itemId) return;

        if (!itemsMap.has(itemId)) {
          const orderTimestamp = order.deliveredDate || order.orderDate || order.createdAt;
          const daysSince = orderTimestamp
            ? Math.floor((Date.now() - new Date(orderTimestamp).getTime()) / (1000 * 60 * 60 * 24))
            : 0;

          itemsMap.set(itemId, {
            id: itemId,
            type: type,
            item: itemData,
            lastOrderedAt: orderTimestamp,
            orderCount: 1,
            daysAgo: daysSince
          });
        } else {
          const existing = itemsMap.get(itemId);
          existing.orderCount++;
        }
      });
    });

    const recentItems = Array.from(itemsMap.values())
      .sort((a, b) => new Date(b.lastOrderedAt) - new Date(a.lastOrderedAt))
      .slice(0, 15);

    console.log(`✅ [DEBUG] Returning ${recentItems.length} unique recent items`);
    if (recentItems.length > 0) {
      console.log(`✅ [DEBUG] Sample item types:`, recentItems.slice(0, 3).map(i => i.type));
    }

    res.json({
      success: true,
      message: "Unified recent items retrieved successfully",
      count: recentItems.length,
      data: recentItems
    });

  } catch (error) {
    console.error("Get recent items error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
});

router.get("/:orderId", protect, async (req, res) => {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.orderId },
      include: {
        customer: { select: { username: true, email: true, phone: true } },
        restaurant: { select: { restaurantName: true, logo: true, phone: true, address: true, city: true, area: true, latitude: true, longitude: true } },
        groceryStore: { select: { storeName: true, logo: true, phone: true, address: true, city: true, area: true, latitude: true, longitude: true } },
        pharmacyStore: { select: { storeName: true, logo: true, phone: true, address: true, city: true, area: true, latitude: true, longitude: true } },
        grabMartStore: { select: { storeName: true, logo: true, phone: true, address: true, city: true, area: true, latitude: true, longitude: true } },
        rider: { select: { username: true, email: true, phone: true } },
        items: {
          include: { food: true, groceryItem: true, pharmacyItem: true, grabMartItem: true }
        }
      }
    });

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    if (req.user.role === "customer" && order.customerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to view this order",
      });
    }

    if (req.user.role === "rider" && order.riderId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to view this order",
      });
    }

    if (req.user.role === "restaurant") {
      const vendorContext = await getVendorContextForUser(req.user);
      const isOwnedByVendor =
        (vendorContext?.restaurantId && order.restaurantId === vendorContext.restaurantId) ||
        (vendorContext?.groceryStoreId && order.groceryStoreId === vendorContext.groceryStoreId) ||
        (vendorContext?.pharmacyStoreId && order.pharmacyStoreId === vendorContext.pharmacyStoreId) ||
        (vendorContext?.grabMartStoreId && order.grabMartStoreId === vendorContext.grabMartStoreId);

      if (!isOwnedByVendor) {
        return res.status(403).json({
          success: false,
          message: "Not authorized to view this order",
        });
      }
    }

    res.json({
      success: true,
      message: "Order retrieved successfully",
      data: sanitizeOrderPayload(order),
    });
  } catch (error) {
    console.error("Get order error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.post(
  "/:orderId/confirm-payment",
  protect,
  [
    body("reference").optional().isString().withMessage("reference must be a string"),
    body("provider").optional().isString().withMessage("provider must be a string"),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { orderId } = req.params;
      const { reference, provider } = req.body;

      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          customerId: true,
          paymentStatus: true,
          status: true,
          fulfillmentMode: true,
          isScheduledOrder: true,
          scheduledForAt: true,
          scheduledReleaseAt: true,
          scheduledReleasedAt: true,
          creditsApplied: true,
          totalAmount: true,
          orderNumber: true,
          paymentReferenceId: true,
        },
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      if (order.customerId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "Not authorized to update this order",
        });
      }

      if (["paid", "successful"].includes(order.paymentStatus)) {
        return res.json({
          success: true,
          message: "Payment already confirmed",
          data: {
            orderId: order.id,
            isScheduledOrder: order.isScheduledOrder === true,
            scheduledForAt: order.scheduledForAt ? new Date(order.scheduledForAt).toISOString() : null,
            scheduledReleaseAt: order.scheduledReleaseAt ? new Date(order.scheduledReleaseAt).toISOString() : null,
          },
        });
      }

      const paymentReference = reference || order.paymentReferenceId || null;
      const requiresExternalPayment = Number(order.totalAmount || 0) > 0;
      const persistedReference =
        paymentReference && paymentReference !== "credits-only" ? paymentReference : undefined;

      if (
        reference &&
        reference !== "credits-only" &&
        order.paymentReferenceId &&
        order.paymentReferenceId !== reference
      ) {
        return res.status(409).json({
          success: false,
          message: "Payment reference mismatch for this order",
        });
      }

      if (requiresExternalPayment) {
        if (!paymentReference || paymentReference === "credits-only") {
          return res.status(400).json({
            success: false,
            message: "Payment reference is required for this order",
          });
        }

        const verification = await paystackService.verifyTransaction(paymentReference);
        if (verification?.status !== "success") {
          return res.status(400).json({
            success: false,
            message: "Payment not verified",
            data: { status: verification?.status },
          });
        }

        const verifiedReference = verification?.reference?.toString();
        if (verifiedReference && verifiedReference !== paymentReference) {
          return res.status(409).json({
            success: false,
            message: "Verified payment reference does not match request reference",
          });
        }

        const expectedAmount = Math.round(Number(order.totalAmount || 0) * 100);
        const verifiedAmount = Number(verification?.amount ?? verification?.amount_in_kobo ?? Number.NaN);
        if (expectedAmount > 0 && Number.isFinite(verifiedAmount) && verifiedAmount !== expectedAmount) {
          return res.status(409).json({
            success: false,
            message: "Verified payment amount does not match order total",
            data: { expectedAmount, verifiedAmount },
          });
        }

        const metadataOrderId =
          verification?.metadata?.orderId?.toString() ||
          verification?.metadata?.order_id?.toString() ||
          null;
        if (metadataOrderId && metadataOrderId !== order.id) {
          return res.status(409).json({
            success: false,
            message: "Verified payment metadata does not match order",
          });
        }
      }

      if (order.creditsApplied > 0) {
        const activeHold = await creditService.getActiveHoldForOrder(req.user.id, order.id);

        if (activeHold) {
          await creditService.applyCreditsToOrder(req.user.id, order.id, order.creditsApplied);
          await creditService.captureHold(req.user.id, order.id);
        } else {
          const existingCredit = await prisma.userCredit.findFirst({
            where: {
              userId: req.user.id,
              orderId: order.id,
              type: "order_payment",
              isActive: true,
            },
          });

          if (!existingCredit) {
            await creditService.applyCreditsToOrder(req.user.id, order.id, order.creditsApplied);
          }
        }
      }

      if (order.fulfillmentMode === "pickup") {
        try {
          await reserveInventoryForOrder({ orderId: order.id });
        } catch (inventoryError) {
          await prisma.order.update({
            where: { id: order.id },
            data: {
              status: "cancelled",
              cancelledDate: new Date(),
              cancellationReason: inventoryError.message || "Unable to reserve inventory for pickup order",
              paymentStatus: "refunded",
              updatedAt: new Date(),
            },
          });

          if (order.creditsApplied > 0) {
            await creditService.releaseHold(req.user.id, order.id).catch(() => null);
          }

          return res.status(409).json({
            success: false,
            message: inventoryError.message || "Unable to reserve inventory. Order cancelled and marked for refund.",
          });
        }
      }

      const shouldConfirmPickup = order.fulfillmentMode === "pickup" && order.status === "pending";
      const shouldKeepScheduledPending =
        order.isScheduledOrder &&
        order.fulfillmentMode === "delivery" &&
        order.status === "pending" &&
        !order.scheduledReleasedAt;

      await prisma.order.update({
        where: { id: order.id },
        data: {
          paymentStatus: "paid",
          paymentProvider: provider || "paystack",
          paymentReferenceId: persistedReference,
          ...(shouldKeepScheduledPending ? { status: "pending" } : {}),
          ...(shouldConfirmPickup
            ? {
                status: "confirmed",
                acceptByAt: new Date(Date.now() + PICKUP_ACCEPT_TIMEOUT_MINUTES * 60 * 1000),
              }
            : {}),
        },
      });

      await createOrderAudit({
        orderId: order.id,
        actorId: req.user.id,
        actorRole: req.user.role,
        action: "payment_confirmed",
        metadata: {
          reference: persistedReference || null,
          provider: provider || "paystack",
          fulfillmentMode: order.fulfillmentMode,
          isScheduledOrder: order.isScheduledOrder === true,
          scheduledForAt: order.scheduledForAt ? new Date(order.scheduledForAt).toISOString() : null,
          scheduledReleaseAt: order.scheduledReleaseAt ? new Date(order.scheduledReleaseAt).toISOString() : null,
        },
      }).catch(() => null);

      try {
        const amount = Number(order.totalAmount || 0);
        const title = "Payment Confirmed";
        const message = shouldKeepScheduledPending
          ? `Payment for scheduled order #${order.orderNumber} (GHS ${amount.toFixed(
              2
            )}) has been confirmed. We'll start processing near your selected delivery time.`
          : `Payment for order #${order.orderNumber} (GHS ${amount.toFixed(2)}) has been confirmed.`;
        const io = getIO();

        await createNotification(
          order.customerId,
          "payment_confirmed",
          title,
          message,
          {
            orderId: order.id,
            orderNumber: order.orderNumber,
            amount,
            route: `/orders/${order.id}`,
          },
          io
        );
      } catch (notifError) {
        console.error("Payment notification error:", notifError.message);
      }

      return res.json({
        success: true,
        message: "Payment confirmed",
        data: {
          orderId: order.id,
          isScheduledOrder: order.isScheduledOrder === true,
          scheduledForAt: order.scheduledForAt ? new Date(order.scheduledForAt).toISOString() : null,
          scheduledReleaseAt: order.scheduledReleaseAt ? new Date(order.scheduledReleaseAt).toISOString() : null,
        },
      });
    } catch (error) {
      console.error("Confirm payment error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/:orderId/pickup/accept",
  protect,
  authorize("restaurant", "admin"),
  async (req, res) => {
    try {
      if (!featureFlags.isPickupVendorOpsEnabled) {
        return res.status(403).json({
          success: false,
          message: "Pickup vendor operations are disabled",
        });
      }

      const { orderId } = req.params;
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          orderNumber: true,
          customerId: true,
          status: true,
          fulfillmentMode: true,
          restaurantId: true,
          groceryStoreId: true,
          pharmacyStoreId: true,
          grabMartStoreId: true,
          acceptedAt: true,
          paymentStatus: true,
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      if (req.user.role === "restaurant") {
        const vendorContext = await getVendorContextForUser(req.user);
        if (!isOrderOwnedByVendorContext(order, vendorContext)) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to manage this order",
          });
        }
      }

      if (order.fulfillmentMode !== "pickup") {
        return res.status(400).json({ success: false, message: "Order is not a pickup order" });
      }

      if (!["confirmed", "preparing"].includes(order.status)) {
        return res.status(400).json({
          success: false,
          message: "Only confirmed pickup orders can be accepted",
        });
      }

      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: {
          status: "preparing",
          acceptedAt: order.acceptedAt || new Date(),
          preparingAt: new Date(),
          rejectReason: null,
          rejectedAt: null,
          updatedAt: new Date(),
        },
      });

      await prisma.orderActionAudit.create({
        data: {
          orderId,
          actorId: req.user.id,
          actorRole: req.user.role,
          action: "pickup_accept",
          metadata: {
            previousStatus: order.status,
            nextStatus: updatedOrder.status,
          },
        },
      });

      notifyOrderStatusChange(updatedOrder, "preparing", "Your pickup order has been accepted and is being prepared.");

      return res.json({
        success: true,
        message: "Pickup order accepted",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      console.error("Pickup accept error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/:orderId/pickup/reject",
  protect,
  authorize("restaurant", "admin"),
  [body("reason").isString().notEmpty().withMessage("reason is required")],
  async (req, res) => {
    try {
      if (!featureFlags.isPickupVendorOpsEnabled) {
        return res.status(403).json({
          success: false,
          message: "Pickup vendor operations are disabled",
        });
      }

      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { orderId } = req.params;
      const { reason } = req.body;

      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          orderNumber: true,
          customerId: true,
          status: true,
          fulfillmentMode: true,
          restaurantId: true,
          groceryStoreId: true,
          pharmacyStoreId: true,
          grabMartStoreId: true,
          paymentStatus: true,
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      if (req.user.role === "restaurant") {
        const vendorContext = await getVendorContextForUser(req.user);
        if (!isOrderOwnedByVendorContext(order, vendorContext)) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to manage this order",
          });
        }
      }

      if (order.fulfillmentMode !== "pickup") {
        return res.status(400).json({ success: false, message: "Order is not a pickup order" });
      }

      if (["cancelled", "picked_up", "delivered"].includes(order.status)) {
        return res.status(400).json({
          success: false,
          message: "Order can no longer be rejected",
        });
      }

      const updatedOrder = await cancelPickupOrder({
        orderId,
        reason,
        refund: true,
        actorId: req.user.id,
        actorRole: req.user.role,
        action: "pickup_reject",
        metadata: {
          previousStatus: order.status,
          rejectedAt: new Date().toISOString(),
        },
      });

      await prisma.order.update({
        where: { id: orderId },
        data: {
          rejectedAt: new Date(),
          rejectReason: reason,
        },
      });

      notifyOrderStatusChange(updatedOrder, "cancelled", `Pickup order was rejected by the store: ${reason}`);

      return res.json({
        success: true,
        message: "Pickup order rejected and refunded",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      console.error("Pickup reject error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/:orderId/pickup/verify-code",
  protect,
  authorize("restaurant", "admin"),
  [body("code").isString().notEmpty().withMessage("code is required")],
  async (req, res) => {
    try {
      if (!featureFlags.isPickupOtpEnabled) {
        return res.status(403).json({
          success: false,
          message: "Pickup OTP verification is disabled",
        });
      }

      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { orderId } = req.params;
      const { code } = req.body;

      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          orderNumber: true,
          customerId: true,
          status: true,
          fulfillmentMode: true,
          restaurantId: true,
          groceryStoreId: true,
          pharmacyStoreId: true,
          grabMartStoreId: true,
          readyAt: true,
          pickupExpiresAt: true,
          pickupOtpHash: true,
          pickupOtpFailedAttempts: true,
          pickupOtpLastAttemptAt: true,
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      if (req.user.role === "restaurant") {
        const vendorContext = await getVendorContextForUser(req.user);
        if (!isOrderOwnedByVendorContext(order, vendorContext)) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to manage this order",
          });
        }
      }

      if (order.fulfillmentMode !== "pickup") {
        return res.status(400).json({ success: false, message: "Order is not a pickup order" });
      }

      if (order.status !== "ready") {
        return res.status(400).json({
          success: false,
          message: "Pickup code verification is only available when order is ready",
        });
      }

      if (!order.pickupOtpHash) {
        return res.status(400).json({
          success: false,
          message: "Pickup code is not set for this order",
        });
      }

      if (order.pickupExpiresAt && new Date(order.pickupExpiresAt).getTime() <= Date.now()) {
        return res.status(400).json({
          success: false,
          message: "Pickup code has expired",
        });
      }

      if (isPickupOtpLocked(order)) {
        return res.status(429).json({
          success: false,
          message: "Pickup code verification is temporarily locked. Try again later.",
        });
      }

      const normalizedCode = String(code).trim();
      const codeHash = hashPickupCode(order.id, normalizedCode);

      if (codeHash !== order.pickupOtpHash) {
        const failedAttempts = (order.pickupOtpFailedAttempts || 0) + 1;
        await prisma.order.update({
          where: { id: order.id },
          data: {
            pickupOtpFailedAttempts: failedAttempts,
            pickupOtpLastAttemptAt: new Date(),
          },
        });

        await prisma.orderActionAudit.create({
          data: {
            orderId,
            actorId: req.user.id,
            actorRole: req.user.role,
            action: "pickup_otp_failed",
            metadata: { failedAttempts },
          },
        });

        return res.status(400).json({
          success: false,
          message:
            failedAttempts >= PICKUP_OTP_MAX_ATTEMPTS
              ? "Too many invalid attempts. Verification is temporarily locked."
              : "Invalid pickup code",
        });
      }

      const pickedUpAt = new Date();
      const pickupDeltaSeconds = order.readyAt
        ? Math.max(0, Math.floor((pickedUpAt.getTime() - new Date(order.readyAt).getTime()) / 1000))
        : null;

      const updatedOrder = await prisma.order.update({
        where: { id: order.id },
        data: {
          status: "picked_up",
          pickedUpAt,
          pickupReadyToCollectedSeconds: pickupDeltaSeconds,
          pickupOtpFailedAttempts: 0,
          pickupOtpLastAttemptAt: null,
          updatedAt: new Date(),
        },
      });

      await prisma.orderActionAudit.create({
        data: {
          orderId,
          actorId: req.user.id,
          actorRole: req.user.role,
          action: "pickup_verified",
          metadata: {
            pickupReadyToCollectedSeconds: pickupDeltaSeconds,
          },
        },
      });

      notifyOrderStatusChange(updatedOrder, "picked_up", "Order pickup verified successfully.");

      return res.json({
        success: true,
        message: "Pickup code verified. Order marked as picked up.",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      console.error("Pickup verify-code error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/:orderId/support/cancel",
  protect,
  authorize("admin"),
  [
    body("reason").isString().notEmpty().withMessage("reason is required"),
    body("refund").optional().isBoolean().withMessage("refund must be a boolean"),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { orderId } = req.params;
      const { reason, refund = true } = req.body;
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          status: true,
          fulfillmentMode: true,
          paymentStatus: true,
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      let updatedOrder = null;
      if (order.fulfillmentMode === "pickup") {
        updatedOrder = await cancelPickupOrder({
          orderId,
          reason,
          refund,
          actorId: req.user.id,
          actorRole: req.user.role,
          action: "support_cancel",
          metadata: { previousStatus: order.status },
        });
      } else {
        updatedOrder = await prisma.order.update({
          where: { id: orderId },
          data: {
            status: "cancelled",
            cancelledDate: new Date(),
            cancellationReason: reason,
            paymentStatus: refund && ["paid", "successful"].includes(order.paymentStatus) ? "refunded" : order.paymentStatus,
            updatedAt: new Date(),
          },
        });

        await createOrderAudit({
          orderId,
          actorId: req.user.id,
          actorRole: req.user.role,
          action: "support_cancel",
          reason,
          metadata: { previousStatus: order.status, refund },
        });
      }

      return res.json({
        success: true,
        message: "Order cancelled by support",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      console.error("Support cancel error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/:orderId/support/refund",
  protect,
  authorize("admin"),
  [body("reason").isString().notEmpty().withMessage("reason is required")],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { orderId } = req.params;
      const { reason } = req.body;

      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: { id: true, status: true, paymentStatus: true, fulfillmentMode: true },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: {
          paymentStatus: "refunded",
          updatedAt: new Date(),
        },
      });

      if (order.fulfillmentMode === "pickup") {
        await releaseInventoryHolds({ orderId }).catch(() => null);
      }

      await createOrderAudit({
        orderId,
        actorId: req.user.id,
        actorRole: req.user.role,
        action: "support_refund",
        reason,
        metadata: {
          previousPaymentStatus: order.paymentStatus,
          currentStatus: order.status,
        },
      });

      return res.json({
        success: true,
        message: "Order refunded by support",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      console.error("Support refund error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/:orderId/support/force-complete",
  protect,
  authorize("admin"),
  [body("reason").isString().notEmpty().withMessage("reason is required")],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { orderId } = req.params;
      const { reason } = req.body;

      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          status: true,
          fulfillmentMode: true,
          readyAt: true,
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      const now = new Date();
      const nextStatus = order.fulfillmentMode === "pickup" ? "picked_up" : "delivered";
      const updateData = {
        status: nextStatus,
        updatedAt: now,
      };

      if (order.fulfillmentMode === "pickup") {
        updateData.pickedUpAt = now;
        if (order.readyAt) {
          updateData.pickupReadyToCollectedSeconds = Math.max(
            0,
            Math.floor((now.getTime() - new Date(order.readyAt).getTime()) / 1000)
          );
        }
      } else {
        updateData.deliveredDate = now;
      }

      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: updateData,
      });

      await createOrderAudit({
        orderId,
        actorId: req.user.id,
        actorRole: req.user.role,
        action: "support_force_complete",
        reason,
        metadata: {
          previousStatus: order.status,
          nextStatus,
        },
      });

      return res.json({
        success: true,
        message: "Order force-completed by support",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      console.error("Support force-complete error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/:orderId/delivery-proof/photo",
  protect,
  authorize("rider", "admin"),
  uploadSingle("photo"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          status: true,
          riderId: true,
          isGiftOrder: true,
          deliveryVerificationRequired: true,
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      if (!order.isGiftOrder || !order.deliveryVerificationRequired) {
        return res.status(400).json({
          success: false,
          message: "Delivery proof upload is only available for gift orders requiring verification",
        });
      }

      if (req.user.role === "rider") {
        if (order.riderId !== req.user.id) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to upload proof for this order",
          });
        }

        if (!DELIVERY_ACTIVE_STATUSES.has(order.status)) {
          return res.status(400).json({
            success: false,
            message: "Delivery proof can only be uploaded while delivery is active",
          });
        }
      }

      if (!req.file || !req.file.cloudinaryUrl) {
        return res.status(400).json({
          success: false,
          message: "No delivery proof photo uploaded",
        });
      }

      await createOrderAudit({
        orderId,
        actorId: req.user.id,
        actorRole: req.user.role,
        action: "gift_delivery_photo_uploaded",
        metadata: {
          photoUrl: req.file.cloudinaryUrl,
          uploadedAt: new Date().toISOString(),
        },
      }).catch(() => null);

      return res.status(201).json({
        success: true,
        message: "Delivery proof photo uploaded successfully",
        data: {
          orderId,
          photoUrl: req.file.cloudinaryUrl,
          blurHash: req.file.blurHash || null,
        },
      });
    } catch (error) {
      console.error("Delivery proof upload error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/:orderId/delivery-code/resend",
  protect,
  [body("target").isIn(["customer", "recipient"]).withMessage("target must be customer or recipient")],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { orderId } = req.params;
      const { target } = req.body;

      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          orderNumber: true,
          customerId: true,
          riderId: true,
          status: true,
          isGiftOrder: true,
          deliveryVerificationRequired: true,
          giftRecipientName: true,
          giftRecipientPhone: true,
          deliveryCodeEncrypted: true,
          deliveryCodeResendCount: true,
          deliveryCodeLastSentAt: true,
          deliveryCodeVerifiedAt: true,
          deliveryVerificationMethod: true,
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      if (!order.isGiftOrder || !order.deliveryVerificationRequired) {
        return res.status(400).json({
          success: false,
          message: "Delivery code resend is only available for gift orders",
        });
      }

      if (!order.deliveryCodeEncrypted) {
        return res.status(400).json({
          success: false,
          message: "Delivery code is unavailable for this order",
        });
      }

      if (["delivered", "cancelled"].includes(order.status)) {
        return res.status(400).json({
          success: false,
          message: "Cannot resend delivery code for completed or cancelled orders",
          code: "DELIVERY_CODE_RESEND_NOT_ALLOWED",
        });
      }

      if (req.user.role === "customer") {
        if (order.customerId !== req.user.id) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to resend code for this order",
          });
        }
      } else if (req.user.role === "rider") {
        if (order.riderId !== req.user.id) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to resend code for this order",
          });
        }
        if (target !== "recipient") {
          return res.status(403).json({
            success: false,
            message: "Riders can only resend code to recipient",
          });
        }
        if (!DELIVERY_ACTIVE_STATUSES.has(order.status)) {
          return res.status(400).json({
            success: false,
            message: "Code can only be resent while delivery is active",
          });
        }
      } else if (req.user.role !== "admin") {
        return res.status(403).json({
          success: false,
          message: "Not authorized to resend delivery codes",
        });
      }

      const resendAvailability = getResendAvailability(order);
      if (!resendAvailability.allowed) {
        return res.status(resendAvailability.status).json({
          success: false,
          message: resendAvailability.message,
          code: resendAvailability.code,
          retryAfterSeconds: resendAvailability.retryAfterSeconds || null,
        });
      }

      const deliveryCode = decryptDeliveryCode(order.deliveryCodeEncrypted);
      let phoneNumber = null;
      let audience = target;

      if (target === "customer") {
        const customer = await prisma.user.findUnique({
          where: { id: order.customerId },
          select: { phone: true },
        });
        phoneNumber = customer?.phone || null;
        if (!phoneNumber) {
          return res.status(400).json({
            success: false,
            message: "Customer phone number is unavailable for this order",
          });
        }
      } else {
        phoneNumber = order.giftRecipientPhone;
        audience = "recipient";
        if (!phoneNumber) {
          return res.status(400).json({
            success: false,
            message: "Gift recipient phone number is unavailable for this order",
          });
        }
      }

      const sendResult = await sendDeliveryCodeSms({
        phoneNumber,
        orderNumber: order.orderNumber,
        code: deliveryCode,
        audience,
        recipientName: order.giftRecipientName,
      });

      if (!sendResult?.success) {
        return res.status(502).json({
          success: false,
          message: sendResult?.message || "Failed to resend delivery code",
          code: "DELIVERY_CODE_RESEND_FAILED",
        });
      }

      const resentAt = new Date();
      await prisma.order.update({
        where: { id: order.id },
        data: {
          deliveryCodeResendCount: { increment: 1 },
          deliveryCodeLastSentAt: resentAt,
        },
      });

      await createOrderAudit({
        orderId: order.id,
        actorId: req.user.id,
        actorRole: req.user.role,
        action: "gift_code_resent",
        metadata: {
          target,
          provider: sendResult.provider || null,
          resentAt: resentAt.toISOString(),
        },
      }).catch(() => null);

      const responseData = {
        orderId: order.id,
        target,
        resentAt: resentAt.toISOString(),
      };

      if (req.user.role === "customer" && target === "customer") {
        responseData.giftDeliveryCode = deliveryCode;
      }

      return res.json({
        success: true,
        message: "Delivery code resent successfully",
        data: responseData,
      });
    } catch (error) {
      if (error instanceof DeliveryVerificationError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          code: error.code || "DELIVERY_VERIFICATION_ERROR",
          ...(error.meta || {}),
        });
      }

      console.error("Delivery code resend error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post("/:orderId/paystack/initialize", protect, async (req, res) => {
  try {
    const { orderId } = req.params;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      select: { id: true, customerId: true, totalAmount: true, paymentStatus: true, orderNumber: true },
    });

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    if (order.customerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to initialize payment for this order",
      });
    }

    if (["paid", "successful"].includes(order.paymentStatus)) {
      return res.status(400).json({
        success: false,
        message: "Order already paid",
      });
    }

    if (order.totalAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Order does not require external payment",
      });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { email: true },
    });

    const email = user?.email || req.user.email;
    if (!email) {
      return res.status(400).json({
        success: false,
        message: "User email is required for Paystack",
      });
    }

    const reference = `ORD-${order.orderNumber}-${Date.now()}`;
    const amount = Math.round(order.totalAmount * 100);

    const init = await paystackService.initializeTransaction({
      email,
      amount,
      reference,
      metadata: { orderId: order.id },
    });

    await prisma.order.update({
      where: { id: order.id },
      data: {
        paymentProvider: "paystack",
        paymentReferenceId: init.reference || reference,
        paymentStatus: "processing",
      },
    });

    return res.json({
      success: true,
      message: "Payment initialized",
      data: {
        authorizationUrl: init.authorization_url,
        reference: init.reference || reference,
        accessCode: init.access_code,
      },
    });
  } catch (error) {
    console.error("Paystack initialize error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.post("/:orderId/release-credit-hold", protect, async (req, res) => {
  try {
    const { orderId } = req.params;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      select: { id: true, customerId: true, creditsApplied: true },
    });

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    if (order.customerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to update this order",
      });
    }

    if (order.creditsApplied > 0) {
      await creditService.releaseHold(req.user.id, order.id);
    }

    return res.json({
      success: true,
      message: "Credit hold released",
      data: { orderId: order.id },
    });
  } catch (error) {
    console.error("Release credit hold error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.put(
  "/:orderId/status",
  protect,
  [
    body("status")
      .isIn([
        "pending",
        "confirmed",
        "preparing",
        "ready",
        "picked_up",
        "on_the_way",
        "delivered",
        "cancelled",
      ])
      .withMessage("Invalid status"),
    body("cancellationReason").optional().isString().withMessage("cancellationReason must be a string"),
    body("deliveryVerification").optional().isObject().withMessage("deliveryVerification must be an object"),
    body("deliveryVerification.method")
      .optional()
      .isIn(["code", "authorized_photo"])
      .withMessage("deliveryVerification.method must be code or authorized_photo"),
    body("deliveryVerification.code").optional().isString().withMessage("deliveryVerification.code must be a string"),
    body("deliveryVerification.photoUrl").optional().isString().withMessage("deliveryVerification.photoUrl must be a string"),
    body("deliveryVerification.reason").optional().isString().withMessage("deliveryVerification.reason must be a string"),
    body("deliveryVerification.contactAttempted")
      .optional()
      .isBoolean()
      .withMessage("deliveryVerification.contactAttempted must be a boolean"),
    body("deliveryVerification.authorizedRecipientName")
      .optional()
      .isString()
      .withMessage("deliveryVerification.authorizedRecipientName must be a string"),
    body("deliveryVerification.riderLat").optional().isFloat().withMessage("deliveryVerification.riderLat must be numeric"),
    body("deliveryVerification.riderLng").optional().isFloat().withMessage("deliveryVerification.riderLng must be numeric"),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { orderId } = req.params;
      const { status, cancellationReason, deliveryVerification } = req.body;

      const order = await prisma.order.findUnique({
        where: { id: orderId }
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      const roleStatusRules = STATUS_UPDATE_ROLE_RULES[req.user.role];
      if (roleStatusRules && !roleStatusRules.has(status)) {
        return res.status(403).json({
          success: false,
          message: `Role ${req.user.role} is not allowed to set status ${status}`,
        });
      }

      if (req.user.role === "customer") {
        if (order.customerId !== req.user.id) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to update this order",
          });
        }
      } else if (req.user.role === "rider") {
        if (order.riderId !== req.user.id) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to update this order",
          });
        }
      } else if (req.user.role === "restaurant") {
        const vendorContext = await getVendorContextForUser(req.user);
        const isOwnedByVendor =
          (vendorContext?.restaurantId && order.restaurantId === vendorContext.restaurantId) ||
          (vendorContext?.groceryStoreId && order.groceryStoreId === vendorContext.groceryStoreId) ||
          (vendorContext?.pharmacyStoreId && order.pharmacyStoreId === vendorContext.pharmacyStoreId) ||
          (vendorContext?.grabMartStoreId && order.grabMartStoreId === vendorContext.grabMartStoreId);

        if (!isOwnedByVendor) {
          return res.status(403).json({
            success: false,
            message: "Not authorized to update this order",
          });
        }
      } else if (req.user.role !== "admin") {
        return res.status(403).json({
          success: false,
          message: "Not authorized to update order status",
        });
      }

      if (order.isScheduledOrder && !order.scheduledReleasedAt && status !== "cancelled" && req.user.role !== "admin") {
        return res.status(409).json({
          success: false,
          message: "Scheduled order is not yet released for processing",
          code: "SCHEDULED_ORDER_NOT_RELEASED",
          scheduledForAt: order.scheduledForAt ? new Date(order.scheduledForAt).toISOString() : null,
          scheduledReleaseAt: order.scheduledReleaseAt ? new Date(order.scheduledReleaseAt).toISOString() : null,
        });
      }

      if (order.fulfillmentMode === "pickup" && status === "picked_up") {
        return res.status(400).json({
          success: false,
          message: "Pickup orders must be marked picked up via OTP verification endpoint",
          code: "PICKUP_OTP_REQUIRED",
        });
      }

      if (status === "delivered" && order.deliveryVerificationRequired) {
        if (!deliveryVerification || typeof deliveryVerification !== "object") {
          return res.status(400).json({
            success: false,
            message: "deliveryVerification is required before marking this order as delivered",
            code: "DELIVERY_VERIFICATION_REQUIRED",
          });
        }

        const method = deliveryVerification.method;
        if (!["code", "authorized_photo"].includes(method)) {
          return res.status(400).json({
            success: false,
            message: "Invalid deliveryVerification.method",
            code: "DELIVERY_VERIFICATION_METHOD_INVALID",
          });
        }

        if (method === "code") {
          if (!deliveryVerification.code || !String(deliveryVerification.code).trim()) {
            return res.status(400).json({
              success: false,
              message: "deliveryVerification.code is required for code verification",
              code: "DELIVERY_CODE_REQUIRED",
            });
          }
        } else {
          if (!deliveryVerification.photoUrl || !String(deliveryVerification.photoUrl).trim()) {
            return res.status(400).json({
              success: false,
              message: "deliveryVerification.photoUrl is required for fallback verification",
              code: "DELIVERY_PROOF_PHOTO_REQUIRED",
            });
          }
          if (!deliveryVerification.reason || !String(deliveryVerification.reason).trim()) {
            return res.status(400).json({
              success: false,
              message: "deliveryVerification.reason is required for fallback verification",
              code: "DELIVERY_PROOF_REASON_REQUIRED",
            });
          }
          if (deliveryVerification.contactAttempted !== true) {
            return res.status(400).json({
              success: false,
              message: "deliveryVerification.contactAttempted must be true for fallback verification",
              code: "DELIVERY_CONTACT_ATTEMPT_REQUIRED",
            });
          }
        }
      }

      let codeVerificationUpdateData = null;
      if (status === "delivered" && order.deliveryVerificationRequired && deliveryVerification?.method === "code") {
        codeVerificationUpdateData = await verifyDeliveryCodeOrThrow({
          tx: prisma,
          order,
          code: deliveryVerification?.code,
          actorId: req.user.id,
          actorRole: req.user.role,
          riderLat: deliveryVerification?.riderLat,
          riderLng: deliveryVerification?.riderLng,
          skipSuccessAudit: true,
        });
      }

      let pickupCodeForNotification = null;

      // Use transaction to update order and handle rider earnings if delivered
      const updatedOrder = await prisma.$transaction(async (tx) => {
        let updateData = {
          status,
          updatedAt: new Date()
        };

        if (order.fulfillmentMode === "pickup") {
          if (status === "preparing") {
            updateData.preparingAt = new Date();
          } else if (status === "ready") {
            const readyAt = new Date();
            const pickupCode = generatePickupCode();
            pickupCodeForNotification = pickupCode;
            updateData.readyAt = readyAt;
            updateData.pickupExpiresAt = new Date(readyAt.getTime() + PICKUP_READY_EXPIRY_MINUTES * 60 * 1000);
            updateData.pickupOtpHash = hashPickupCode(order.id, pickupCode);
            updateData.pickupOtpFailedAttempts = 0;
            updateData.pickupOtpLastAttemptAt = null;
          } else if (status === "picked_up") {
            const pickedUpAt = new Date();
            updateData.pickedUpAt = pickedUpAt;
            if (order.readyAt) {
              updateData.pickupReadyToCollectedSeconds = Math.max(
                0,
                Math.floor((pickedUpAt.getTime() - new Date(order.readyAt).getTime()) / 1000)
              );
            }
          }
        }

        if (status === "delivered") {
          if (order.deliveryVerificationRequired) {
            const latestVerificationState = await tx.order.findUnique({
              where: { id: orderId },
              select: {
                id: true,
                deliveryCodeVerifiedAt: true,
                deliveryVerificationMethod: true,
              },
            });

            if (!latestVerificationState) {
              throw new DeliveryVerificationError("Order not found", 404, "ORDER_NOT_FOUND");
            }

            const method = deliveryVerification?.method;
            if (method === "code") {
              if (
                latestVerificationState.deliveryCodeVerifiedAt ||
                latestVerificationState.deliveryVerificationMethod === "authorized_photo"
              ) {
                throw new DeliveryVerificationError(
                  "Delivery verification has already been completed for this order",
                  400,
                  "DELIVERY_VERIFICATION_ALREADY_COMPLETED"
                );
              }

              updateData = {
                ...updateData,
                ...codeVerificationUpdateData,
              };

              await tx.orderActionAudit.create({
                data: {
                  orderId,
                  actorId: req.user.id,
                  actorRole: req.user.role,
                  action: "gift_code_verified",
                  metadata: {
                    riderLat: Number.isFinite(Number(deliveryVerification?.riderLat))
                      ? Number(deliveryVerification.riderLat)
                      : null,
                    riderLng: Number.isFinite(Number(deliveryVerification?.riderLng))
                      ? Number(deliveryVerification.riderLng)
                      : null,
                    verifiedAt: codeVerificationUpdateData?.deliveryCodeVerifiedAt
                      ? new Date(codeVerificationUpdateData.deliveryCodeVerifiedAt).toISOString()
                      : new Date().toISOString(),
                  },
                },
              });
            } else if (method === "authorized_photo") {
              if (
                latestVerificationState.deliveryCodeVerifiedAt ||
                latestVerificationState.deliveryVerificationMethod === "authorized_photo"
              ) {
                throw new DeliveryVerificationError(
                  "Delivery verification has already been completed for this order",
                  400,
                  "DELIVERY_VERIFICATION_ALREADY_COMPLETED"
                );
              }

              updateData.deliveryVerificationMethod = "authorized_photo";
              updateData.deliveryProofPhotoUrl = String(deliveryVerification.photoUrl).trim();
              updateData.deliveryProofReason = String(deliveryVerification.reason).trim();
              updateData.deliveryProofCapturedAt = new Date();
              updateData.deliveryVerificationLat = Number.isFinite(Number(deliveryVerification?.riderLat))
                ? Number(deliveryVerification.riderLat)
                : null;
              updateData.deliveryVerificationLng = Number.isFinite(Number(deliveryVerification?.riderLng))
                ? Number(deliveryVerification.riderLng)
                : null;

              await tx.orderActionAudit.create({
                data: {
                  orderId,
                  actorId: req.user.id,
                  actorRole: req.user.role,
                  action: "gift_delivered_fallback",
                  metadata: {
                    reason: updateData.deliveryProofReason,
                    photoUrl: updateData.deliveryProofPhotoUrl,
                    contactAttempted: deliveryVerification?.contactAttempted === true,
                    authorizedRecipientName: deliveryVerification?.authorizedRecipientName || null,
                    riderLat: updateData.deliveryVerificationLat,
                    riderLng: updateData.deliveryVerificationLng,
                  },
                },
              });
            }
          }

          updateData.deliveredDate = new Date();

          if (order.riderId) {
            // Check if transaction already exists for this order
            const existingTransaction = await tx.transaction.findFirst({
              where: {
                referenceId: order.id,
                type: "delivery",
                userId: order.riderId,
              }
            });

            if (!existingTransaction) {
              const deliveryFee = order.deliveryFee || 0;

              if (deliveryFee > 0) {
                // Find or create rider wallet
                let wallet = await tx.riderWallet.findUnique({
                  where: { userId: order.riderId }
                });

                if (!wallet) {
                  wallet = await tx.riderWallet.create({
                    data: { userId: order.riderId }
                  });
                }

                // Create transaction
                await tx.transaction.create({
                  data: {
                    walletId: wallet.id,
                    userId: order.riderId,
                    amount: deliveryFee,
                    type: "delivery",
                    description: `Delivery fee for order ${order.orderNumber}`,
                    referenceId: order.id,
                    status: "completed",
                  }
                });

                // Update wallet balance (simplified logic: incremental update)
                await tx.riderWallet.update({
                  where: { id: wallet.id },
                  data: {
                    balance: { increment: deliveryFee },
                    totalEarnings: { increment: deliveryFee }
                  }
                });
              }
            }
          }
        } else if (status === "cancelled") {
          updateData.cancelledDate = new Date();
          if (cancellationReason) {
            updateData.cancellationReason = cancellationReason;
          }
        }

        return await tx.order.update({
          where: { id: orderId },
          data: updateData,
          include: {
            customer: { select: { username: true, email: true, phone: true } },
            restaurant: { select: { restaurantName: true, logo: true, address: true, city: true, area: true, latitude: true, longitude: true } },
            groceryStore: { select: { storeName: true, logo: true, address: true, city: true, area: true, latitude: true, longitude: true } },
            pharmacyStore: { select: { storeName: true, logo: true, address: true, city: true, area: true, latitude: true, longitude: true } },
            grabMartStore: { select: { storeName: true, logo: true, address: true, city: true, area: true, latitude: true, longitude: true } },
            rider: { select: { username: true, email: true, phone: true } }
          }
        });
      });

      if (status === "cancelled" && order.creditsApplied > 0) {
        await creditService.releaseHold(order.customerId, order.id);
      }

      if (status === "cancelled" && order.fulfillmentMode === "pickup") {
        await releaseInventoryHolds({ orderId }).catch(() => null);
      }

      await createOrderAudit({
        orderId,
        actorId: req.user.id,
        actorRole: req.user.role,
        action: `status_${status}`,
        reason: status === "cancelled" ? (cancellationReason || null) : null,
        metadata: {
          previousStatus: order.status,
          nextStatus: status,
          fulfillmentMode: order.fulfillmentMode,
          deliveryVerificationMethod:
            status === "delivered" && order.deliveryVerificationRequired
              ? (deliveryVerification?.method || null)
              : null,
        },
      }).catch(() => null);

      // Send push notification to customer about order status change
      const io = getIO();
      const pickupReadyMessage =
        status === "ready" && updatedOrder.fulfillmentMode === "pickup" && pickupCodeForNotification
          ? `Your order is ready for pickup. Show this code at the store: ${pickupCodeForNotification}`
          : null;
      notifyOrderStatusChange(updatedOrder, status, pickupReadyMessage, io);

      if (
        status === "on_the_way" &&
        order.status !== "on_the_way" &&
        order.isGiftOrder &&
        order.deliveryVerificationRequired &&
        order.giftRecipientPhone &&
        order.deliveryCodeEncrypted
      ) {
        try {
          const deliveryCode = decryptDeliveryCode(order.deliveryCodeEncrypted);
          const recipientSendResult = await sendDeliveryCodeSms({
            phoneNumber: order.giftRecipientPhone,
            orderNumber: updatedOrder.orderNumber,
            code: deliveryCode,
            audience: "recipient",
            recipientName: order.giftRecipientName,
          });

          await createOrderAudit({
            orderId,
            actorId: req.user.id,
            actorRole: req.user.role,
            action: "gift_code_sent_recipient",
            metadata: {
              trigger: "status_on_the_way",
              success: !!recipientSendResult?.success,
              provider: recipientSendResult?.provider || null,
              errorMessage: recipientSendResult?.success ? null : (recipientSendResult?.message || null),
            },
          }).catch(() => null);
        } catch (giftNotifyError) {
          console.error("Gift recipient on_the_way notification error:", giftNotifyError.message);
        }
      }

      // Reset rider delivery status when order is delivered or cancelled
      if ((status === 'delivered' || status === 'cancelled') && order.riderId) {
        try {
          const RiderStatus = require('../models/RiderStatus');
          await RiderStatus.findOneAndUpdate(
            { riderId: order.riderId },
            { $set: { isOnDelivery: false, currentOrderId: null } }
          );
          console.log(`📍 Reset delivery status for rider ${order.riderId} (order ${status})`);
        } catch (statusError) {
          console.error("Reset rider delivery status error:", statusError);
        }
      }

      // Trigger dispatch when order is confirmed and doesn't have a rider yet
      if (
        ['confirmed', 'preparing', 'ready'].includes(status) &&
        !updatedOrder.riderId &&
        updatedOrder.fulfillmentMode !== 'pickup'
      ) {
        console.log(`🚀 Triggering dispatch for order ${updatedOrder.orderNumber} (status: ${status})`);

        // Run dispatch asynchronously to not block the response
        dispatchService.dispatchOrder(orderId).then(result => {
          if (result.success) {
            console.log(`✅ Dispatch initiated for order ${updatedOrder.orderNumber} -> rider ${result.riderName}`);
          } else {
            console.log(`⚠️ Dispatch failed for order ${updatedOrder.orderNumber}: ${result.error}`);
          }
        }).catch(err => {
          console.error(`❌ Dispatch error for order ${updatedOrder.orderNumber}:`, err.message);
        });
      }

      // Cancel reservations if order is cancelled
      if (status === 'cancelled') {
        dispatchService.cancelOrderReservations(orderId).catch(err => {
          console.error(`Error cancelling reservations for order ${orderId}:`, err.message);
        });
      }

      res.json({
        success: true,
        message: "Order status updated successfully",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      if (error instanceof DeliveryVerificationError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          code: error.code || "DELIVERY_VERIFICATION_ERROR",
          ...(error.meta || {}),
        });
      }

      console.error("Update order status error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.put(
  "/:orderId/assign-rider",
  protect,
  authorize("admin", "rider"),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const { riderId } = req.body;

      const order = await prisma.order.findUnique({
        where: { id: orderId }
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      if (order.isScheduledOrder && !order.scheduledReleasedAt) {
        return res.status(409).json({
          success: false,
          message: "Scheduled order is not yet released for rider assignment",
          code: "SCHEDULED_ORDER_NOT_RELEASED",
          scheduledForAt: order.scheduledForAt ? new Date(order.scheduledForAt).toISOString() : null,
          scheduledReleaseAt: order.scheduledReleaseAt ? new Date(order.scheduledReleaseAt).toISOString() : null,
        });
      }

      const rider = await prisma.user.findUnique({
        where: { id: riderId }
      });

      if (!rider || rider.role !== "rider") {
        return res.status(400).json({
          success: false,
          message: "Invalid rider",
        });
      }

      let statusUpdate = {};
      if (order.status === "ready") {
        statusUpdate = { status: "picked_up" };
      }

      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: {
          riderId: riderId,
          ...statusUpdate
        },
        include: {
          rider: { select: { username: true, email: true, phone: true } },
          customer: { select: { username: true, email: true, phone: true } }
        }
      });

      // Notify rider about new assignment
      notifyRiderAssignment(riderId, updatedOrder);

      // Notify customer that a rider has been assigned
      const io = getIO();
      const statusToNotify = updatedOrder.status === 'picked_up' ? 'picked_up' : 'confirmed';
      const customMsg = updatedOrder.status === 'picked_up'
        ? `${rider.username} is picking up your order!`
        : `${rider.username} has been assigned to your order.`;

      notifyOrderStatusChange(updatedOrder, statusToNotify, customMsg, io);

      res.json({
        success: true,
        message: "Rider assigned successfully",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      console.error("Assign rider error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

module.exports = router;
