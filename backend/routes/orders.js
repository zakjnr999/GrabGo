const express = require("express");
const { body, validationResult } = require("express-validator");
const prisma = require("../config/prisma");
const { protect, authorize } = require("../middleware/auth");
const { uploadSingle, uploadToCloudinary } = require("../middleware/upload");
const { cacheMiddleware, invalidateCache } = require("../middleware/cache");
const { paymentAttemptRateLimit } = require("../middleware/fraud_rate_limit");
const cache = require("../utils/cache");
const trackingService = require("../services/tracking_service");
const { sendOrderNotification, sendToUser } = require("../services/fcm_service");
const { createNotification } = require("../services/notification_service");
const ReferralService = require("../services/referral_service");
const creditService = require("../services/credit_service");
const { calculateOrderPricing } = require("../services/pricing_service");
const paystackService = require("../services/paystack_service");
const { getIO } = require("../utils/socket");
const dispatchService = require("../services/dispatch_service");
const dispatchRetryService = require("../services/dispatch_retry_service");
const featureFlags = require("../config/feature_flags");
const { createScopedLogger } = require("../utils/logger");
const { createOrdersRouteHelpers } = require("./support/orders_route_helpers");
const {
  OrderItemResolutionError,
  createOrderItemResolutionHelpers,
} = require("./support/order_item_resolution_helpers");
const { createOrderStatusSideEffectsHelpers } = require("./support/order_status_side_effects_helpers");
const { createOrderDeliveryVerificationHelpers } = require("./support/order_delivery_verification_helpers");
const { createOrderPickupStatusUpdateHelpers } = require("./support/order_pickup_status_update_helpers");
const {
  RiderAssignmentRouteError,
  createOrderRiderAssignmentHelpers,
} = require("./support/order_rider_assignment_helpers");
const {
  PickupVendorOpError,
  createOrderPickupVendorOpsHelpers,
} = require("./support/order_pickup_vendor_ops_helpers");
const {
  DeliveryCodeResendRouteError,
  createOrderDeliveryCodeResendHelpers,
} = require("./support/order_delivery_code_resend_helpers");
const {
  SupportOrderOpError,
  createOrderSupportOpsHelpers,
} = require("./support/order_support_ops_helpers");
const {
  DeliveryProofUploadError,
  createOrderDeliveryProofHelpers,
} = require("./support/order_delivery_proof_helpers");
const {
  OrderPaymentInitializationError,
  createOrderPaystackInitializeHelpers,
} = require("./support/order_paystack_initialize_helpers");
const metrics = require("../utils/metrics");
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
  validateScheduledVendorAvailability,
  normalizeDeliveryTimeType,
} = require("../services/scheduled_order_service");
const {
  createOrderAudit,
  reserveInventoryForOrder,
  releaseInventoryHolds,
  cancelPickupOrder,
} = require("../services/pickup_order_service");
const { isVendorAcceptingScheduledOrders } = require("../utils/scheduled_orders");
const {
  CodPolicyError,
  COD_NO_SHOW_REASON,
  isCodNoShowReason,
  getCodExternalPaymentAmount,
  getCodRemainingCashAmount,
  validateCodNoShowEvidence,
  evaluateCodEligibility,
  isCodDispatchAllowedStatus,
} = require("../services/cod_service");
const { resolveFoodCustomization } = require("../services/food_customization_service");
const {
  ACTION_TYPES,
  buildFraudContextFromRequest,
  fraudDecisionService,
  applyFraudDecision,
} = require("../services/fraud");

const console = createScopedLogger("orders_route");
const {
  VendorRatingError,
  decorateOrdersWithVendorRatingMeta,
  submitVendorRating,
} = require("../services/vendor_rating_service");
const {
  ItemReviewError,
  decorateOrdersWithItemReviewMeta,
  submitItemReviews,
} = require("../services/item_review_service");

const router = express.Router();

const { FOOD_INCLUDE_RELATIONS, formatFoodResponse } = require('../utils/food_helpers');

const {
  invalidateFoodOrderHistoryCaches,
  normalizeFulfillmentMode,
  normalizePromoCode,
  decrementPromoUsageIfNeeded,
  reservePromoUsage,
  PICKUP_OTP_MAX_ATTEMPTS,
  PICKUP_ACCEPT_TIMEOUT_MINUTES,
  PICKUP_READY_EXPIRY_MINUTES,
  DELIVERY_ACTIVE_STATUSES,
  STATUS_UPDATE_ROLE_RULES,
  canTransitionOrderStatus,
  shouldTriggerDispatchForStatus,
  ORDER_TO_TRACKING_STATUS_MAP,
  shouldTriggerDispatchForOrder,
  queueDispatchRetryIfNeeded,
  safeDispatchRetrySideEffect,
  generatePickupCode,
  hashPickupCode,
  isPickupOtpLocked,
  sanitizeOrderPayload,
  computeGroupMetaForOrders,
  getVendorContextForUser,
  isOrderOwnedByVendorContext,
  normalizeGiftRecipientPhone,
  notifyOrderStatusChange,
  notifyRiderAssignment,
  generateOrderNumber,
} = createOrdersRouteHelpers({
  prisma,
  invalidateCache,
  cache,
  featureFlags,
  dispatchRetryService,
  isCodDispatchAllowedStatus,
  getCodExternalPaymentAmount,
  getCodRemainingCashAmount,
  normalizeGhanaPhone,
  sendOrderNotification,
  sendToUser,
  createNotification,
  getIO,
  logger: console,
});
const { resolveOrderItemsForCreateOrder } = createOrderItemResolutionHelpers({
  prisma,
  resolveFoodCustomization,
});
const {
  ensureDeliveryVerificationPayload,
  resolveCodeVerificationUpdateData,
  applyDeliveredVerificationUpdate,
} = createOrderDeliveryVerificationHelpers({
  DeliveryVerificationError,
  verifyDeliveryCodeOrThrow,
});
const { applyPickupStatusUpdate } = createOrderPickupStatusUpdateHelpers({
  generatePickupCode,
  hashPickupCode,
  PICKUP_READY_EXPIRY_MINUTES,
});
const {
  ensureOrderCanAssignRider,
  assignRiderAndNotify,
} = createOrderRiderAssignmentHelpers({
  prisma,
  shouldTriggerDispatchForOrder,
  notifyRiderAssignment,
  notifyOrderStatusChange,
  getIO,
});
const {
  ensureVendorCanManagePickupOrder,
  acceptPickupOrderAndNotify,
  ensurePickupOrderRejectable,
  ensurePickupCodeCanBeVerified,
  verifyPickupCodeAndCompleteOrder,
} = createOrderPickupVendorOpsHelpers({
  prisma,
  hashPickupCode,
  isPickupOtpLocked,
  PICKUP_OTP_MAX_ATTEMPTS,
  notifyOrderStatusChange,
});
const {
  ensureDeliveryCodeResendAllowed,
  resendDeliveryCode,
} = createOrderDeliveryCodeResendHelpers({
  prisma,
  DELIVERY_ACTIVE_STATUSES,
  getResendAvailability,
  decryptDeliveryCode,
  sendDeliveryCodeSms,
  createOrderAudit,
});
const {
  ensureSupportOrderExists,
  cancelOrderBySupport,
  refundOrderBySupport,
  forceCompleteOrderBySupport,
} = createOrderSupportOpsHelpers({
  prisma,
  cancelPickupOrder,
  decrementPromoUsageIfNeeded,
  createOrderAudit,
  releaseInventoryHolds,
  sanitizeOrderPayload,
});
const {
  ensureDeliveryProofUploadAllowed,
  recordDeliveryProofUpload,
} = createOrderDeliveryProofHelpers({
  DELIVERY_ACTIVE_STATUSES,
  createOrderAudit,
});
const {
  ensureOrderCanInitializePayment,
  initializePaystackPaymentForOrder,
} = createOrderPaystackInitializeHelpers({
  prisma,
  paystackService,
  getCodExternalPaymentAmount,
});
const { runOrderStatusPostUpdateSideEffects } = createOrderStatusSideEffectsHelpers({
  creditService,
  releaseInventoryHolds,
  createOrderAudit,
  getIO,
  notifyOrderStatusChange,
  decryptDeliveryCode,
  sendDeliveryCodeSms,
  safeDispatchRetrySideEffect,
  queueDispatchRetryIfNeeded,
  dispatchService,
  dispatchRetryService,
  trackingService,
  shouldTriggerDispatchForOrder,
  ORDER_TO_TRACKING_STATUS_MAP,
  COD_NO_SHOW_REASON,
  logger: console,
});

router.post(
  "/",
  protect,
  [
    body("restaurant").optional({ nullable: true }).isString().withMessage("restaurant must be a string"),
    body("fulfillmentMode").optional().isIn(["delivery", "pickup"]).withMessage("Invalid fulfillment mode"),
    body("deliveryTimeType").optional().isIn(["asap", "scheduled"]).withMessage("Invalid delivery time type"),
    body("scheduledForAt")
      .optional()
      .isISO8601({ strict: true, strictSeparator: true })
      .withMessage("scheduledForAt must be a valid ISO datetime"),
    body("items")
      .isArray({ min: 1 })
      .withMessage("At least one item is required"),
    body("items.*.selectedPortionId")
      .optional({ nullable: true })
      .isString()
      .withMessage("items.*.selectedPortionId must be a string"),
    body("items.*.selectedPreferenceOptionIds")
      .optional({ nullable: true })
      .custom((value) => {
        if (value === null || value === undefined) return true;
        if (Array.isArray(value)) return true;
        if (typeof value === "object") return true;
        if (typeof value === "string") return true;
        return false;
      })
      .withMessage("items.*.selectedPreferenceOptionIds must be an array, object, or string"),
    body("items.*.itemNote")
      .optional({ nullable: true })
      .isString()
      .withMessage("items.*.itemNote must be a string"),
    body("deliveryAddress").optional(),
    body("pickupContactName").optional({ nullable: true }).isString().withMessage("pickupContactName must be a string"),
    body("pickupContactPhone").optional({ nullable: true }).isString().withMessage("pickupContactPhone must be a string"),
    body("acceptNoShowPolicy").optional({ nullable: true }).isBoolean().withMessage("acceptNoShowPolicy must be a boolean"),
    body("isGiftOrder").optional({ nullable: true }).isBoolean().withMessage("isGiftOrder must be a boolean"),
    body("giftRecipientName").optional({ nullable: true }).isString().withMessage("giftRecipientName must be a string"),
    body("giftRecipientPhone").optional({ nullable: true }).isString().withMessage("giftRecipientPhone must be a string"),
    body("giftNote").optional({ nullable: true }).isString().withMessage("giftNote must be a string"),
    body("paymentMethod")
      .isIn(["card", "cash"])
      .withMessage("Invalid payment method"),
    body("useCredits").optional({ nullable: true }).isBoolean().withMessage("useCredits must be a boolean"),
    body("promoCode").optional({ nullable: true }).isString().withMessage("promoCode must be a string"),
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
        promoCode,
        notes,
        noShowPolicyVersion,
        orderNumber: bodyOrderNumber
      } = req.body;

      const fulfillmentMode = normalizeFulfillmentMode(rawFulfillmentMode);
      const isPickupMode = fulfillmentMode === "pickup";
      const isDeliveryMode = !isPickupMode;
      const normalizedPaymentMethod = String(paymentMethod || "").trim().toLowerCase();
      const normalizedPromoCode = normalizePromoCode(promoCode);
      const isCashOnDelivery = normalizedPaymentMethod === "cash";
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

      if (isCashOnDelivery) {
        if (!featureFlags.isCodEnabled) {
          return res.status(403).json({
            success: false,
            message: "Cash on delivery is currently unavailable",
            code: "COD_DISABLED",
          });
        }

        if (!isDeliveryMode) {
          return res.status(400).json({
            success: false,
            message: "Cash on delivery is only supported for delivery orders",
            code: "COD_DELIVERY_ONLY",
          });
        }
      }

      if (normalizedPromoCode && !featureFlags.isPromoCheckoutEnabled) {
        return res.status(403).json({
          success: false,
          message: "Promo codes are temporarily unavailable",
          code: "PROMO_DISABLED",
        });
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

      const orderNumber = bodyOrderNumber || await generateOrderNumber();
      let subtotal = 0;
      let maxItemPrepMinutes = 0;
      let orderItemsData = [];
      let resolvedOrderType = null;
      let resolvedVendorId = null;
      try {
        ({
          subtotal,
          maxItemPrepMinutes,
          orderItemsData,
          resolvedOrderType,
          resolvedVendorId,
        } = await resolveOrderItemsForCreateOrder({ items }));
      } catch (error) {
        if (error instanceof OrderItemResolutionError) {
          return res.status(error.status || 400).json({
            success: false,
            message: error.message,
          });
        }
        throw error;
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

      const openingHoursSelect = {
        select: {
          dayOfWeek: true,
          openTime: true,
          closeTime: true,
          isClosed: true,
        },
      };

      let vendorDoc = null;
      if (resolvedOrderType === "food") {
        vendorDoc = await prisma.restaurant.findUnique({
          where: { id: resolvedVendorId },
          select: {
            restaurantName: true,
            deliveryFee: true,
            latitude: true,
            longitude: true,
            averagePreparationTime: true,
            averageDeliveryTime: true,
            status: true,
            isDeleted: true,
            isAcceptingOrders: true,
            isOpen: true,
            features: true,
            openingHours: openingHoursSelect,
          },
        });
      } else if (resolvedOrderType === "grocery") {
        vendorDoc = await prisma.groceryStore.findUnique({
          where: { id: resolvedVendorId },
          select: {
            storeName: true,
            deliveryFee: true,
            latitude: true,
            longitude: true,
            averagePreparationTime: true,
            averageDeliveryTime: true,
            status: true,
            isDeleted: true,
            isAcceptingOrders: true,
            isOpen: true,
            features: true,
            openingHours: openingHoursSelect,
          },
        });
      } else if (resolvedOrderType === "pharmacy") {
        vendorDoc = await prisma.pharmacyStore.findUnique({
          where: { id: resolvedVendorId },
          select: {
            storeName: true,
            deliveryFee: true,
            latitude: true,
            longitude: true,
            averagePreparationTime: true,
            averageDeliveryTime: true,
            status: true,
            isDeleted: true,
            isAcceptingOrders: true,
            isOpen: true,
            features: true,
            openingHours: openingHoursSelect,
          },
        });
      } else if (resolvedOrderType === "grabmart") {
        vendorDoc = await prisma.grabMartStore.findUnique({
          where: { id: resolvedVendorId },
          select: {
            storeName: true,
            deliveryFee: true,
            latitude: true,
            longitude: true,
            status: true,
            isDeleted: true,
            isAcceptingOrders: true,
            isOpen: true,
            is24Hours: true,
            features: true,
          },
        });
      }

      if (!vendorDoc || vendorDoc.status !== "approved") {
        return res.status(404).json({
          success: false,
          message: "Store/restaurant not found or inactive",
        });
      }
      if (vendorDoc.isDeleted === true || vendorDoc.isAcceptingOrders === false) {
        return res.status(400).json({
          success: false,
          message: "Store is currently unavailable for new orders",
        });
      }
      if (!isScheduledOrderRequested && vendorDoc.isOpen === false) {
        return res.status(400).json({
          success: false,
          message: "Store is currently closed",
        });
      }

      if (isScheduledOrderRequested) {
        const isVendorScheduledEnabled = isVendorAcceptingScheduledOrders(vendorDoc);
        if (!isVendorScheduledEnabled) {
          return res.status(400).json({
            success: false,
            message: `${vendorDoc.restaurantName || vendorDoc.storeName || "Vendor"} is not accepting scheduled orders right now`,
            code: "SCHEDULED_ORDER_VENDOR_DISABLED",
            vendorType: resolvedOrderType,
          });
        }

        try {
          validateScheduledVendorAvailability({
            isOpen: vendorDoc.isOpen,
            is24Hours: vendorDoc.is24Hours === true,
            openingHours: vendorDoc.openingHours || [],
            scheduledWindowStartAt,
            scheduledWindowEndAt,
            vendorType: resolvedOrderType,
            vendorName: vendorDoc.restaurantName || vendorDoc.storeName || "Vendor",
            allowClosedNow: true,
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
        orderType: resolvedOrderType,
        promoCode: normalizedPromoCode,
      });

      if (normalizedPromoCode && pricing.promoValidationMessage) {
        return res.status(400).json({
          success: false,
          message: pricing.promoValidationMessage,
          code: "PROMO_VALIDATION_FAILED",
        });
      }

      const tax = pricing.tax;
      let totalAmount = pricing.total;
      let codUpfrontAmount = null;
      let codRemainingAmount = null;

      if (isCashOnDelivery) {
        if (featureFlags.codMaxOrderTotalGhs > 0 && pricing.total > featureFlags.codMaxOrderTotalGhs) {
          return res.status(400).json({
            success: false,
            message: `Cash on delivery is limited to orders up to GHS ${featureFlags.codMaxOrderTotalGhs.toFixed(2)}`,
            code: "COD_MAX_ORDER_TOTAL_EXCEEDED",
          });
        }

        const codEligibility = await evaluateCodEligibility({
          prisma,
          customerId: req.user.id,
          minPrepaidDeliveredOrders: featureFlags.codMinPrepaidDeliveredOrders,
          noShowDisableThreshold: featureFlags.codNoShowDisableThreshold,
          requirePhoneVerified: featureFlags.codRequirePhoneVerified,
          maxConcurrentCodOrders: featureFlags.codMaxConcurrentOrders,
        });

        if (!codEligibility.eligible) {
          return res.status(codEligibility.status || 403).json({
            success: false,
            message: codEligibility.message,
            code: codEligibility.code,
            data: codEligibility.metrics,
          });
        }

        codUpfrontAmount = getCodExternalPaymentAmount(
          { deliveryFee: pricing.deliveryFee, rainFee: pricing.rainFee },
          { includeRainFee: featureFlags.codUpfrontIncludeRainFee }
        );

        if (codUpfrontAmount <= 0) {
          return res.status(400).json({
            success: false,
            message: "Cash on delivery is unavailable for orders without a delivery-fee commitment",
            code: "COD_UPFRONT_AMOUNT_INVALID",
          });
        }

        codRemainingAmount = getCodRemainingCashAmount(
          { totalAmount: pricing.total, deliveryFee: pricing.deliveryFee, rainFee: pricing.rainFee },
          { includeRainFee: featureFlags.codUpfrontIncludeRainFee }
        );
      }

      const shouldUseCredits = !isCashOnDelivery && useCredits !== false;
      // Apply credits if available
      const creditResult = await creditService.calculateCreditApplication(req.user.id, totalAmount, shouldUseCredits);
      const creditApplied = creditResult?.creditsApplied || 0;
      if (creditApplied > 0) {
        totalAmount = creditResult.remainingPayment;
      }
      const isCreditOnly = !isCashOnDelivery && creditApplied > 0 && totalAmount <= 0;

      const orderCreateFraudContext = buildFraudContextFromRequest({
        req,
        actionType: ACTION_TYPES.ORDER_CREATE,
        actorType: req.user.role || "customer",
        actorId: req.user.id,
        extras: {
          orderId: orderNumber,
          amount: Number(totalAmount || 0),
          paymentMethod: normalizedPaymentMethod,
          metadata: {
            orderType: resolvedOrderType,
            itemCount: Array.isArray(items) ? items.length : 0,
            accountAgeMinutes: null,
            newPaymentMethod: Boolean(req.body?.newPaymentMethod),
            deliveryCity: isDeliveryMode ? (deliveryAddress?.city || null) : null,
            promoCode: pricing.promoCode || null,
          },
        },
      });

      const orderCreateFraudDecision = await fraudDecisionService.evaluate({
        actionType: ACTION_TYPES.ORDER_CREATE,
        actorType: req.user.role || "customer",
        actorId: req.user.id,
        context: orderCreateFraudContext,
      });

      const orderCreateFraudGate = applyFraudDecision({
        req,
        res,
        decision: orderCreateFraudDecision,
        actionType: ACTION_TYPES.ORDER_CREATE,
      });
      if (orderCreateFraudGate.blocked || orderCreateFraudGate.challenged) return;

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
        promoCode: pricing.promoCode || null,
        promoDiscount: Number(pricing.promoDiscount || 0),
        promoType: pricing.promoType || null,
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
        paymentMethod: normalizedPaymentMethod,
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

      // Create order and consume promo usage atomically
      const order = await prisma.$transaction(async (tx) => {
        if (pricing.promoCode) {
          const promoUsageResult = await reservePromoUsage(tx, pricing.promoCode);
          if (!promoUsageResult.success) {
            const promoUsageError = new Error(promoUsageResult.message || "Promo code validation failed");
            promoUsageError.isPromoValidationError = true;
            throw promoUsageError;
          }
        }

        return tx.order.create({
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
          await decrementPromoUsageIfNeeded({ promoCode: order.promoCode });

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

      if (isCashOnDelivery) {
        await createOrderAudit({
          orderId: order.id,
          actorId: req.user.id,
          actorRole: req.user.role,
          action: "cod_order_created",
          metadata: {
            upfrontAmount: codUpfrontAmount,
            remainingCashOnDelivery: codRemainingAmount,
            includeRainFeeInUpfront: featureFlags.codUpfrontIncludeRainFee,
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
      if (isCashOnDelivery) {
        responseOrder.cod = {
          upfrontAmount: codUpfrontAmount,
          remainingCashOnDelivery: codRemainingAmount,
          includeRainFeeInUpfront: featureFlags.codUpfrontIncludeRainFee,
        };
      }

      if (resolvedOrderType === "food") {
        await invalidateFoodOrderHistoryCaches().catch((cacheError) => {
          console.error("Food order-history cache invalidation error:", cacheError.message);
        });
      }

      res.status(201).json({
        success: true,
        message: "Order created successfully",
        data: responseOrder,
      });
      metrics.recordOrderEvent({ action: "create", result: "success" });
    } catch (error) {
      if (error instanceof ScheduledOrderError) {
        metrics.recordOrderEvent({ action: "create", result: error.code || "scheduled_order_error" });
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          code: error.code || "SCHEDULED_ORDER_ERROR",
          ...(error.meta || {}),
        });
      }
      if (error instanceof CodPolicyError) {
        metrics.recordOrderEvent({ action: "create", result: error.code || "cod_policy_error" });
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          code: error.code || "COD_POLICY_ERROR",
          ...(error.meta || {}),
        });
      }
      if (error?.isPromoValidationError) {
        metrics.recordOrderEvent({ action: "create", result: "promo_validation_failed" });
        return res.status(400).json({
          success: false,
          message: error.message || "Promo code validation failed",
          code: "PROMO_VALIDATION_FAILED",
        });
      }

      console.error("Create order error:", error);
      metrics.recordOrderEvent({ action: "create", result: "failure" });
      res.status(500).json({
        success: false,
        message: "Server error",
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
        vendorReview: {
          select: {
            rating: true,
            createdAt: true,
          },
        },
        items: {
          include: {
            food: true,
            groceryItem: true,
            pharmacyItem: true,
            grabMartItem: true,
            itemReview: {
              select: {
                rating: true,
                createdAt: true,
              },
            },
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const ordersWithGroupMeta = await computeGroupMetaForOrders(orders);
    const ordersWithVendorRatingMeta = decorateOrdersWithVendorRatingMeta(ordersWithGroupMeta, {
      viewerRole: req.user.role,
    });
    const ordersWithItemReviewMeta = decorateOrdersWithItemReviewMeta(
      ordersWithVendorRatingMeta,
      {
        viewerRole: req.user.role,
      }
    );

    res.json({
      success: true,
      message: "Orders retrieved successfully",
      data: sanitizeOrderPayload(ordersWithItemReviewMeta),
    });
  } catch (error) {
    console.error("Get orders error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
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
    });
  }
});

router.get("/cod/eligibility", protect, async (req, res) => {
  try {
    if (req.user.role !== "customer") {
      return res.status(403).json({
        success: false,
        message: "Only customers can check COD eligibility",
      });
    }

    if (!featureFlags.isCodEnabled) {
      return res.status(403).json({
        success: false,
        message: "Cash on delivery is currently unavailable",
        code: "COD_DISABLED",
      });
    }

    const eligibility = await evaluateCodEligibility({
      prisma,
      customerId: req.user.id,
      minPrepaidDeliveredOrders: featureFlags.codMinPrepaidDeliveredOrders,
      noShowDisableThreshold: featureFlags.codNoShowDisableThreshold,
      requirePhoneVerified: featureFlags.codRequirePhoneVerified,
      maxConcurrentCodOrders: featureFlags.codMaxConcurrentOrders,
    });

    if (!eligibility.eligible) {
      return res.status(eligibility.status || 403).json({
        success: false,
        message: eligibility.message,
        code: eligibility.code,
        data: eligibility.metrics,
      });
    }

    return res.json({
      success: true,
      message: eligibility.message,
      code: eligibility.code,
      data: eligibility.metrics,
    });
  } catch (error) {
    console.error("COD eligibility error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error",
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
        vendorReview: {
          select: {
            rating: true,
            createdAt: true,
          },
        },
        items: {
          include: {
            food: true,
            groceryItem: true,
            pharmacyItem: true,
            grabMartItem: true,
            itemReview: {
              select: {
                rating: true,
                createdAt: true,
              },
            },
          }
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

    const [orderWithGroupMeta] = await computeGroupMetaForOrders([order]);
    const orderWithVendorRatingMeta = decorateOrdersWithVendorRatingMeta(orderWithGroupMeta || order, {
      viewerRole: req.user.role,
    });
    const orderWithItemReviewMeta = decorateOrdersWithItemReviewMeta(
      orderWithVendorRatingMeta,
      {
        viewerRole: req.user.role,
      }
    );

    res.json({
      success: true,
      message: "Order retrieved successfully",
      data: sanitizeOrderPayload(orderWithItemReviewMeta),
    });
  } catch (error) {
    console.error("Get order error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

router.post(
  "/:orderId/vendor-rating",
  protect,
  [
    body("rating")
      .isInt({ min: 1, max: 5 })
      .withMessage("rating must be an integer between 1 and 5"),
    body("feedbackTags")
      .optional()
      .isArray({ max: 10 })
      .withMessage("feedbackTags must be an array with at most 10 items"),
    body("feedbackTags.*")
      .optional()
      .isString()
      .withMessage("feedbackTags entries must be strings"),
    body("comment")
      .optional()
      .isString()
      .isLength({ max: 500 })
      .withMessage("comment must be at most 500 characters"),
  ],
  async (req, res) => {
    try {
      if (req.user.role !== "customer") {
        return res.status(403).json({
          success: false,
          message: "Only customers can submit vendor ratings",
          code: "VENDOR_RATING_CUSTOMER_ONLY",
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

      const result = await submitVendorRating({
        orderId: req.params.orderId,
        customerId: req.user.id,
        rating: req.body.rating,
        feedbackTags: req.body.feedbackTags,
        comment: req.body.comment,
      });

      return res.status(201).json({
        success: true,
        message: "Vendor rating submitted successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof VendorRatingError) {
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      console.error("Submit vendor rating error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  }
);

router.post(
  "/:orderId/item-reviews",
  protect,
  [
    body("reviews")
      .isArray({ min: 1, max: 25 })
      .withMessage("reviews must be a non-empty array with at most 25 items"),
    body("reviews.*.orderItemId")
      .isString()
      .notEmpty()
      .withMessage("orderItemId is required for each item review"),
    body("reviews.*.rating")
      .isInt({ min: 1, max: 5 })
      .withMessage("rating must be an integer between 1 and 5"),
    body("reviews.*.feedbackTags")
      .optional()
      .isArray({ max: 10 })
      .withMessage("feedbackTags must be an array with at most 10 items"),
    body("reviews.*.feedbackTags.*")
      .optional()
      .isString()
      .withMessage("feedbackTags entries must be strings"),
    body("reviews.*.comment")
      .optional()
      .isString()
      .isLength({ max: 500 })
      .withMessage("comment must be at most 500 characters"),
  ],
  async (req, res) => {
    try {
      if (req.user.role !== "customer") {
        return res.status(403).json({
          success: false,
          message: "Only customers can submit item reviews",
          code: "ITEM_REVIEW_CUSTOMER_ONLY",
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

      const result = await submitItemReviews({
        orderId: req.params.orderId,
        customerId: req.user.id,
        reviews: req.body.reviews,
      });

      return res.status(201).json({
        success: true,
        message: "Item reviews submitted successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof ItemReviewError) {
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      console.error("Submit item reviews error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  }
);

router.post(
  "/:orderId/confirm-payment",
  protect,
  paymentAttemptRateLimit,
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
          paymentMethod: true,
          paymentStatus: true,
          orderType: true,
          status: true,
          fulfillmentMode: true,
          riderId: true,
          isScheduledOrder: true,
          scheduledForAt: true,
          scheduledReleaseAt: true,
          scheduledReleasedAt: true,
          creditsApplied: true,
          deliveryFee: true,
          rainFee: true,
          totalAmount: true,
          orderNumber: true,
          paymentReferenceId: true,
          isGiftOrder: true,
          deliveryCodeEncrypted: true,
          promoCode: true,
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
        let dispatchCandidate = order;
        const shouldPromoteAlreadyPaidDeliveryToConfirmed =
          featureFlags.isConfirmedPredispatchEnabled &&
          order.fulfillmentMode === "delivery" &&
          order.status === "pending" &&
          (!order.isScheduledOrder || !!order.scheduledReleasedAt);

        if (shouldPromoteAlreadyPaidDeliveryToConfirmed) {
          await prisma.order.update({
            where: { id: order.id },
            data: { status: "confirmed" },
          });
          dispatchCandidate = { ...order, status: "confirmed" };
        }

        if (
          dispatchCandidate.fulfillmentMode !== "pickup" &&
          !dispatchCandidate.riderId &&
          shouldTriggerDispatchForOrder(
            dispatchCandidate,
            dispatchCandidate.status,
          )
        ) {
          dispatchService.dispatchOrder(dispatchCandidate.id).then(async (result) => {
            if (result.success) {
              console.log(
                `✅ Dispatch initiated for already-paid order ${dispatchCandidate.orderNumber}`,
              );
              await safeDispatchRetrySideEffect(
                `mark retry resolved for already-paid (${dispatchCandidate.id})`,
                () =>
                  dispatchRetryService.markRetryResolved(
                    dispatchCandidate.id,
                    "dispatch_succeeded"
                  )
              );
            } else {
              console.log(
                `⚠️ Dispatch deferred for already-paid order ${dispatchCandidate.orderNumber}: ${result.error}`,
              );
              await safeDispatchRetrySideEffect(
                `enqueue retry for already-paid dispatch failure (${dispatchCandidate.id})`,
                () =>
                  queueDispatchRetryIfNeeded({
                    orderId: dispatchCandidate.id,
                    orderNumber: dispatchCandidate.orderNumber,
                    result,
                    source: "orders:already_paid_confirm",
                  })
              );
            }
          }).catch(async (err) => {
            console.error(
              `❌ Dispatch error for already-paid order ${dispatchCandidate.orderNumber}:`,
              err.message,
            );
            await safeDispatchRetrySideEffect(
              `enqueue retry for already-paid dispatch exception (${dispatchCandidate.id})`,
              () =>
                dispatchRetryService.enqueueDispatchRetry({
                  orderId: dispatchCandidate.id,
                  orderNumber: dispatchCandidate.orderNumber,
                  reason: "dispatch_exception",
                  source: "orders:already_paid_confirm",
                  delaySeconds: 30,
                  metadata: { error: err.message },
                })
            );
          });
        }

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
      const externalPaymentAmount = order.paymentMethod === "cash"
        ? getCodExternalPaymentAmount(order, { includeRainFee: featureFlags.codUpfrontIncludeRainFee })
        : Number(order.totalAmount || 0);
      const requiresExternalPayment = externalPaymentAmount > 0;
      const persistedReference =
        paymentReference && paymentReference !== "credits-only" ? paymentReference : undefined;
      const sourceOfTruthEnabled =
        featureFlags.isPaymentWebhookSourceOfTruthEnabled &&
        requiresExternalPayment;

      const confirmPaymentFraudContext = buildFraudContextFromRequest({
        req,
        actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
        actorType: req.user.role || "customer",
        actorId: req.user.id,
        extras: {
          orderId: order.id,
          paymentRef: persistedReference || null,
          amount: Number(externalPaymentAmount || 0),
          currency: "GHS",
          metadata: {
            orderNumber: order.orderNumber,
            paymentMethod: order.paymentMethod,
            sourceOfTruthEnabled,
          },
        },
      });

      const confirmPaymentFraudDecision = await fraudDecisionService.evaluate({
        actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
        actorType: req.user.role || "customer",
        actorId: req.user.id,
        context: confirmPaymentFraudContext,
      });

      const confirmPaymentFraudGate = applyFraudDecision({
        req,
        res,
        decision: confirmPaymentFraudDecision,
        actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
      });
      if (confirmPaymentFraudGate.blocked || confirmPaymentFraudGate.challenged) return;

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

        const expectedAmount = Math.round(externalPaymentAmount * 100);
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

      if (sourceOfTruthEnabled) {
        await prisma.order.update({
          where: { id: order.id },
          data: {
            paymentProvider: provider || "paystack",
            paymentReferenceId: persistedReference,
            paymentStatus: "processing",
          },
        });

        await prisma.payment.upsert({
          where: { referenceId: persistedReference },
          update: {
            provider: provider || "paystack",
            status: "processing",
            metadata: {
              clientConfirmAdvisory: true,
              webhookConfirmationPending: true,
            },
          },
          create: {
            orderId: order.id,
            customerId: order.customerId,
            paymentMethod: order.paymentMethod,
            provider: provider || "paystack",
            amount: Number(externalPaymentAmount || order.totalAmount || 0),
            status: "processing",
            referenceId: persistedReference,
            metadata: {
              clientConfirmAdvisory: true,
              webhookConfirmationPending: true,
            },
          },
        }).catch(() => null);

        await createOrderAudit({
          orderId: order.id,
          actorId: req.user.id,
          actorRole: req.user.role,
          action: "payment_confirm_advisory",
          metadata: {
            reference: persistedReference || null,
            provider: provider || "paystack",
            paymentScope: order.paymentMethod === "cash" ? "cod_delivery_fee" : "full_order_payment",
            externalPaymentAmount,
            sourceOfTruth: "webhook",
          },
        }).catch(() => null);

        return res.json({
          success: true,
          message: "Payment verification received. Awaiting webhook confirmation.",
          data: {
            orderId: order.id,
            paymentStatus: "processing",
            paymentScope: order.paymentMethod === "cash" ? "cod_delivery_fee" : "full_order_payment",
            externalPaymentAmount,
            webhookRequired: true,
          },
        });
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
          await decrementPromoUsageIfNeeded({ promoCode: order.promoCode });

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
      const shouldConfirmDeliveryAfterPayment =
        featureFlags.isConfirmedPredispatchEnabled &&
        order.fulfillmentMode === "delivery" &&
        order.status === "pending" &&
        !shouldKeepScheduledPending;

      await prisma.order.update({
        where: { id: order.id },
        data: {
          paymentStatus: "paid",
          paymentProvider: provider || "paystack",
          paymentReferenceId: persistedReference,
          ...(shouldKeepScheduledPending ? { status: "pending" } : {}),
          ...(shouldConfirmDeliveryAfterPayment ? { status: "confirmed" } : {}),
          ...(shouldConfirmPickup
            ? {
                status: "confirmed",
                acceptByAt: new Date(Date.now() + PICKUP_ACCEPT_TIMEOUT_MINUTES * 60 * 1000),
              }
            : {}),
        },
      });

      // If vendor already moved the order into a dispatchable state before payment settled,
      // kick off dispatch now that payment is confirmed.
      const orderAfterPayment = await prisma.order.findUnique({
        where: { id: order.id },
        select: {
          id: true,
          orderNumber: true,
          status: true,
          paymentStatus: true,
          paymentMethod: true,
          fulfillmentMode: true,
          riderId: true,
        },
      });

      if (
        orderAfterPayment &&
        orderAfterPayment.fulfillmentMode !== "pickup" &&
        !orderAfterPayment.riderId &&
        ["paid", "successful"].includes(orderAfterPayment.paymentStatus) &&
        shouldTriggerDispatchForOrder(orderAfterPayment, orderAfterPayment.status)
      ) {
        dispatchService.dispatchOrder(order.id).then(async (result) => {
          if (result.success) {
            console.log(`✅ Dispatch initiated after payment for order ${orderAfterPayment.orderNumber}`);
            await safeDispatchRetrySideEffect(
              `mark retry resolved after payment (${order.id})`,
              () => dispatchRetryService.markRetryResolved(order.id, "dispatch_succeeded")
            );
          } else {
            console.log(`⚠️ Dispatch deferred after payment for order ${orderAfterPayment.orderNumber}: ${result.error}`);
            await safeDispatchRetrySideEffect(
              `enqueue retry after payment dispatch failure (${order.id})`,
              () =>
                queueDispatchRetryIfNeeded({
                  orderId: order.id,
                  orderNumber: orderAfterPayment.orderNumber,
                  result,
                  source: "orders:payment_confirmed",
                })
            );
          }
        }).catch(async (err) => {
          console.error(`❌ Dispatch error after payment for order ${orderAfterPayment.orderNumber}:`, err.message);
          await safeDispatchRetrySideEffect(
            `enqueue retry after payment dispatch exception (${order.id})`,
            () =>
              dispatchRetryService.enqueueDispatchRetry({
                orderId: order.id,
                orderNumber: orderAfterPayment.orderNumber,
                reason: "dispatch_exception",
                source: "orders:payment_confirmed",
                delaySeconds: 30,
                metadata: { error: err.message },
              })
          );
        });
      }

      await createOrderAudit({
        orderId: order.id,
        actorId: req.user.id,
        actorRole: req.user.role,
        action: "payment_confirmed",
        metadata: {
          reference: persistedReference || null,
          provider: provider || "paystack",
          paymentScope: order.paymentMethod === "cash" ? "cod_delivery_fee" : "full_order_payment",
          externalPaymentAmount,
          codRemainingCashAmount: order.paymentMethod === "cash"
            ? getCodRemainingCashAmount(order, { includeRainFee: featureFlags.codUpfrontIncludeRainFee })
            : null,
          fulfillmentMode: order.fulfillmentMode,
          isScheduledOrder: order.isScheduledOrder === true,
          scheduledForAt: order.scheduledForAt ? new Date(order.scheduledForAt).toISOString() : null,
          scheduledReleaseAt: order.scheduledReleaseAt ? new Date(order.scheduledReleaseAt).toISOString() : null,
        },
      }).catch(() => null);

      try {
        const amount = Number(externalPaymentAmount || 0);
        const codRemainingCashAmount = order.paymentMethod === "cash"
          ? getCodRemainingCashAmount(order, { includeRainFee: featureFlags.codUpfrontIncludeRainFee })
          : null;
        const title = "Payment Confirmed";
        let giftDeliveryCodeForNotification = null;
        if (order.isGiftOrder && order.deliveryCodeEncrypted) {
          try {
            giftDeliveryCodeForNotification = decryptDeliveryCode(order.deliveryCodeEncrypted);
          } catch (giftCodeError) {
            console.error("Gift code decrypt error for payment notification:", giftCodeError.message);
          }
        }

        const baseMessage = order.paymentMethod === "cash"
          ? `Delivery-fee payment for COD order #${order.orderNumber} (GHS ${amount.toFixed(
              2
            )}) has been confirmed. Remaining cash due on delivery: GHS ${(codRemainingCashAmount || 0).toFixed(2)}.`
          : shouldKeepScheduledPending
          ? `Payment for scheduled order #${order.orderNumber} (GHS ${amount.toFixed(
              2
            )}) has been confirmed. We'll start processing near your selected delivery time.`
          : `Payment for order #${order.orderNumber} (GHS ${amount.toFixed(2)}) has been confirmed.`;
        const message = giftDeliveryCodeForNotification
          ? `${baseMessage} Your gift delivery code is ${giftDeliveryCodeForNotification}.`
          : baseMessage;
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
            paymentScope: order.paymentMethod === "cash" ? "cod_delivery_fee" : "full_order_payment",
            ...(order.paymentMethod === "cash" ? { codRemainingCashAmount } : {}),
            route: `/orders/${order.id}`,
            ...(giftDeliveryCodeForNotification ? { giftDeliveryCode: giftDeliveryCodeForNotification } : {}),
          },
          io
        );
      } catch (notifError) {
        console.error("Payment notification error:", notifError.message);
      }

      if (order.orderType === "food") {
        await invalidateFoodOrderHistoryCaches().catch((cacheError) => {
          console.error("Food order-history cache invalidation error:", cacheError.message);
        });
      }

      return res.json({
        success: true,
        message: "Payment confirmed",
        data: {
          orderId: order.id,
          paymentScope: order.paymentMethod === "cash" ? "cod_delivery_fee" : "full_order_payment",
          externalPaymentAmount,
          codRemainingCashAmount: order.paymentMethod === "cash"
            ? getCodRemainingCashAmount(order, { includeRainFee: featureFlags.codUpfrontIncludeRainFee })
            : null,
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

      const vendorContext = req.user.role === "restaurant" ? await getVendorContextForUser(req.user) : null;
      ensureVendorCanManagePickupOrder({
        order,
        userRole: req.user.role,
        vendorContext,
      });

      const updatedOrder = await acceptPickupOrderAndNotify({
        orderId,
        order,
        actorId: req.user.id,
        actorRole: req.user.role,
        sanitizeOrderPayload,
      });

      return res.json({
        success: true,
        message: "Pickup order accepted",
        data: updatedOrder,
      });
    } catch (error) {
      if (error instanceof PickupVendorOpError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
        });
      }
      console.error("Pickup accept error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
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

      const vendorContext = req.user.role === "restaurant" ? await getVendorContextForUser(req.user) : null;
      ensureVendorCanManagePickupOrder({
        order,
        userRole: req.user.role,
        vendorContext,
      });
      ensurePickupOrderRejectable({ order });

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
        data: updatedOrder,
      });
    } catch (error) {
      if (error instanceof PickupVendorOpError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
        });
      }
      console.error("Pickup reject error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
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

      const vendorContext = req.user.role === "restaurant" ? await getVendorContextForUser(req.user) : null;
      ensureVendorCanManagePickupOrder({
        order,
        userRole: req.user.role,
        vendorContext,
      });
      ensurePickupCodeCanBeVerified({ order });

      const updatedOrder = await verifyPickupCodeAndCompleteOrder({
        orderId,
        order,
        code,
        actorId: req.user.id,
        actorRole: req.user.role,
        sanitizeOrderPayload,
      });

      return res.json({
        success: true,
        message: "Pickup code verified. Order marked as picked up.",
        data: updatedOrder,
      });
    } catch (error) {
      if (error instanceof PickupVendorOpError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
        });
      }
      console.error("Pickup verify-code error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
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
          promoCode: true,
        },
      });

      if (!order) {
        return res.status(404).json({ success: false, message: "Order not found" });
      }

      const updatedOrder = await cancelOrderBySupport({
        orderId,
        order,
        reason,
        refund,
        actorId: req.user.id,
        actorRole: req.user.role,
      });

      return res.json({
        success: true,
        message: "Order cancelled by support",
        data: updatedOrder,
      });
    } catch (error) {
      if (error instanceof SupportOrderOpError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
        });
      }
      console.error("Support cancel error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
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

      const updatedOrder = await refundOrderBySupport({
        orderId,
        order,
        reason,
        actorId: req.user.id,
        actorRole: req.user.role,
      });

      return res.json({
        success: true,
        message: "Order refunded by support",
        data: updatedOrder,
      });
    } catch (error) {
      if (error instanceof SupportOrderOpError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
        });
      }
      console.error("Support refund error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
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

      const updatedOrder = await forceCompleteOrderBySupport({
        orderId,
        order,
        reason,
        actorId: req.user.id,
        actorRole: req.user.role,
      });

      return res.json({
        success: true,
        message: "Order force-completed by support",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      if (error instanceof SupportOrderOpError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
        });
      }
      console.error("Support force-complete error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
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

      ensureDeliveryProofUploadAllowed({
        order,
        actor: req.user,
        file: req.file,
      });

      const responseData = await recordDeliveryProofUpload({
        orderId,
        actor: req.user,
        file: req.file,
      });

      return res.status(201).json({
        success: true,
        message: "Delivery proof photo uploaded successfully",
        data: responseData,
      });
    } catch (error) {
      if (error instanceof DeliveryProofUploadError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
        });
      }
      console.error("Delivery proof upload error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
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

      ensureDeliveryCodeResendAllowed({
        order,
        target,
        actor: req.user,
      });

      const responseData = await resendDeliveryCode({
        order,
        target,
        actor: req.user,
      });

      return res.json({
        success: true,
        message: "Delivery code resent successfully",
        data: responseData,
      });
    } catch (error) {
      if (error instanceof DeliveryVerificationError || error instanceof DeliveryCodeResendRouteError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
          ...(error.meta || {}),
        });
      }

      console.error("Delivery code resend error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  }
);

router.post("/:orderId/paystack/initialize", protect, paymentAttemptRateLimit, async (req, res) => {
  try {
    const { orderId } = req.params;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        customerId: true,
        totalAmount: true,
        deliveryFee: true,
        rainFee: true,
        paymentMethod: true,
        paymentStatus: true,
        orderNumber: true,
      },
    });

    const { externalPaymentAmount } = ensureOrderCanInitializePayment({
      order,
      actorId: req.user.id,
      includeRainFee: featureFlags.codUpfrontIncludeRainFee,
    });

    const reference = `ORD-${order.orderNumber}-${Date.now()}`;
    const initPaymentFraudContext = buildFraudContextFromRequest({
      req,
      actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
      actorType: req.user.role || "customer",
      actorId: req.user.id,
      extras: {
        orderId: order.id,
        paymentRef: reference,
        amount: Number(externalPaymentAmount || 0),
        currency: "GHS",
        metadata: {
          stage: "paystack_initialize",
          paymentMethod: order.paymentMethod,
        },
      },
    });

    const initPaymentFraudDecision = await fraudDecisionService.evaluate({
      actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
      actorType: req.user.role || "customer",
      actorId: req.user.id,
      context: initPaymentFraudContext,
    });

    const initPaymentFraudGate = applyFraudDecision({
      req,
      res,
      decision: initPaymentFraudDecision,
      actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
    });
    if (initPaymentFraudGate.blocked || initPaymentFraudGate.challenged) return;

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

    const paymentData = await initializePaystackPaymentForOrder({
      order,
      email,
      externalPaymentAmount,
      reference,
    });

    return res.json({
      success: true,
      message: "Payment initialized",
      data: paymentData,
    });
  } catch (error) {
    if (error instanceof OrderPaymentInitializationError) {
      return res.status(error.status || 400).json({
        success: false,
        message: error.message,
        ...(error.code ? { code: error.code } : {}),
      });
    }
    console.error("Paystack initialize error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
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
    body("noShowEvidence").optional().isObject().withMessage("noShowEvidence must be an object"),
    body("noShowEvidence.photoUrl").optional().isString().withMessage("noShowEvidence.photoUrl must be a string"),
    body("noShowEvidence.contactAttempts")
      .optional()
      .isInt({ min: 0 })
      .withMessage("noShowEvidence.contactAttempts must be an integer"),
    body("noShowEvidence.waitedMinutes")
      .optional()
      .isFloat({ min: 0 })
      .withMessage("noShowEvidence.waitedMinutes must be numeric"),
    body("noShowEvidence.riderLat").optional().isFloat().withMessage("noShowEvidence.riderLat must be numeric"),
    body("noShowEvidence.riderLng").optional().isFloat().withMessage("noShowEvidence.riderLng must be numeric"),
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
      const { status, cancellationReason, deliveryVerification, noShowEvidence } = req.body;

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

      if (order.status === status) {
        return res.json({
          success: true,
          message: `Order is already ${status}`,
          data: sanitizeOrderPayload(order),
        });
      }

      const fulfillmentStatuses = new Set(["confirmed", "preparing", "ready", "picked_up", "on_the_way", "delivered"]);
      const isPrepaid = order.paymentMethod !== "cash";
      if (
        featureFlags.isPrepaidFulfillmentGuardEnabled &&
        isPrepaid &&
        fulfillmentStatuses.has(status) &&
        !["paid", "successful"].includes(order.paymentStatus)
      ) {
        return res.status(409).json({
          success: false,
          message: "Prepaid order cannot move to fulfillment before webhook-confirmed payment",
          code: "PREPAID_PAYMENT_NOT_CONFIRMED",
          data: {
            paymentStatus: order.paymentStatus,
            requiredStatus: "paid",
          },
        });
      }

      const fulfillmentFraudContext = buildFraudContextFromRequest({
        req,
        actionType: ACTION_TYPES.ORDER_FULFILLMENT_TRANSITION,
        actorType: req.user.role,
        actorId: req.user.id,
        extras: {
          orderId,
          paymentState: order.paymentStatus,
          status,
          metadata: {
            currentStatus: order.status,
            nextStatus: status,
            paymentMethod: order.paymentMethod,
            isScheduledOrder: Boolean(order.isScheduledOrder),
          },
        },
      });

      const fulfillmentFraudDecision = await fraudDecisionService.evaluate({
        actionType: ACTION_TYPES.ORDER_FULFILLMENT_TRANSITION,
        actorType: req.user.role,
        actorId: req.user.id,
        context: fulfillmentFraudContext,
      });

      const fulfillmentFraudGate = applyFraudDecision({
        req,
        res,
        decision: fulfillmentFraudDecision,
        actionType: ACTION_TYPES.ORDER_FULFILLMENT_TRANSITION,
      });
      if (fulfillmentFraudGate.blocked || fulfillmentFraudGate.challenged) return;

      if (!canTransitionOrderStatus(order.status, status, req.user.role)) {
        return res.status(409).json({
          success: false,
          message: `Invalid order status transition from ${order.status} to ${status}`,
          code: "INVALID_ORDER_STATUS_TRANSITION",
          currentStatus: order.status,
          requestedStatus: status,
        });
      }

      const rawCancellationReason = typeof cancellationReason === "string" ? cancellationReason.trim() : "";
      const isCodNoShowCancellation =
        status === "cancelled" &&
        order.paymentMethod === "cash" &&
        isCodNoShowReason(rawCancellationReason);
      let normalizedCancellationReason = rawCancellationReason || null;
      let normalizedNoShowEvidence = null;

      if (isCodNoShowCancellation) {
        if (!["rider", "admin"].includes(req.user.role)) {
          return res.status(403).json({
            success: false,
            message: "Only rider or admin can confirm COD no-show cancellation",
            code: "COD_NO_SHOW_NOT_AUTHORIZED",
          });
        }
        normalizedNoShowEvidence = validateCodNoShowEvidence(noShowEvidence);
        normalizedCancellationReason = COD_NO_SHOW_REASON;
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

      ensureDeliveryVerificationPayload({
        status,
        order,
        deliveryVerification,
      });

      const codeVerificationUpdateData = await resolveCodeVerificationUpdateData({
        tx: prisma,
        status,
        order,
        deliveryVerification,
        actorId: req.user.id,
        actorRole: req.user.role,
      });

      let pickupCodeForNotification = null;

      // Use transaction to update order and handle rider earnings if delivered
      const updatedOrder = await prisma.$transaction(async (tx) => {
        let updateData = {
          status,
          updatedAt: new Date()
        };

        if (status === "confirmed" && !order.acceptedAt) {
          updateData.acceptedAt = new Date();
        }

        ({
          updateData,
          pickupCodeForNotification,
        } = applyPickupStatusUpdate({
          order,
          status,
          updateData,
        }));

        if (status === "delivered") {
          updateData = await applyDeliveredVerificationUpdate({
            tx,
            orderId,
            order,
            deliveryVerification,
            codeVerificationUpdateData,
            updateData,
            actorId: req.user.id,
            actorRole: req.user.role,
          });

          updateData.deliveredDate = new Date();

          if (order.riderId) {
            // Use delivery settlement service (credits riderEarnings, not deliveryFee)
            const { settleDeliveryInTransaction } = require('../services/delivery_settlement_service');
            await settleDeliveryInTransaction({
              tx,
              order,
              riderId: order.riderId,
              orderType: order.orderType || 'food',
            });
          }
        } else if (status === "cancelled") {
          updateData.cancelledDate = new Date();
          if (normalizedCancellationReason) {
            updateData.cancellationReason = normalizedCancellationReason;
          }
          await decrementPromoUsageIfNeeded({ tx, promoCode: order.promoCode });
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

      await runOrderStatusPostUpdateSideEffects({
        orderId,
        order,
        updatedOrder,
        status,
        actorId: req.user.id,
        actorRole: req.user.role,
        normalizedCancellationReason,
        normalizedNoShowEvidence,
        deliveryVerification,
        pickupCodeForNotification,
        isCodNoShowCancellation,
      });

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
      if (error instanceof CodPolicyError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          code: error.code || "COD_POLICY_ERROR",
          ...(error.meta || {}),
        });
      }

      console.error("Update order status error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  }
);

router.put(
  "/:orderId/assign-rider",
  protect,
  authorize("admin"),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const { riderId: requestedRiderId } = req.body;
      const riderId = requestedRiderId;

      const order = await prisma.order.findUnique({
        where: { id: orderId }
      });

      ensureOrderCanAssignRider({ order, riderId });

      const rider = await prisma.user.findUnique({
        where: { id: riderId }
      });

      if (!rider || rider.role !== "rider") {
        return res.status(400).json({
          success: false,
          message: "Invalid rider",
        });
      }

      const updatedOrder = await assignRiderAndNotify({
        orderId,
        order,
        riderId,
        rider,
      });

      res.json({
        success: true,
        message: "Rider assigned successfully",
        data: sanitizeOrderPayload(updatedOrder),
      });
    } catch (error) {
      if (error instanceof RiderAssignmentRouteError) {
        return res.status(error.status || 400).json({
          success: false,
          message: error.message,
          ...(error.code ? { code: error.code } : {}),
          ...(error.meta || {}),
        });
      }
      console.error("Assign rider error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  }
);

module.exports = router;
