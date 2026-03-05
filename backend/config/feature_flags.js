const isProduction = process.env.NODE_ENV === 'production';

const parseFlag = (name, defaultValue) => {
  const rawValue = process.env[name];
  if (rawValue === undefined || rawValue === null || rawValue === '') {
    return defaultValue;
  }

  const normalized = String(rawValue).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return defaultValue;
};

const parseIntFlag = (name, defaultValue, { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const rawValue = process.env[name];
  if (rawValue === undefined || rawValue === null || rawValue === '') {
    return defaultValue;
  }

  const parsed = Number.parseInt(String(rawValue), 10);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return defaultValue;
  }
  return parsed;
};

const parseFloatFlag = (name, defaultValue, { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const rawValue = process.env[name];
  if (rawValue === undefined || rawValue === null || rawValue === '') {
    return defaultValue;
  }

  const parsed = Number.parseFloat(String(rawValue));
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return defaultValue;
  }
  return parsed;
};

const defaultPickupEnabled = !isProduction;

module.exports = {
  isPickupCheckoutEnabled: parseFlag('PICKUP_CHECKOUT_ENABLED', defaultPickupEnabled),
  isPickupVendorOpsEnabled: parseFlag('PICKUP_VENDOR_OPS_ENABLED', defaultPickupEnabled),
  isPickupOtpEnabled: parseFlag('PICKUP_OTP_ENABLED', defaultPickupEnabled),
  isPickupReadyExpiryEnabled: parseFlag('PICKUP_READY_EXPIRY_ENABLED', defaultPickupEnabled),
  isGiftOrdersEnabled: parseFlag('GIFT_ORDERS_ENABLED', false),
  isScheduledOrdersEnabled: parseFlag('SCHEDULED_ORDERS_ENABLED', false),
  isConfirmedPredispatchEnabled: parseFlag('CONFIRMED_PREDISPATCH_ENABLED', false),
  isMixedCartEnabled: parseFlag('MIXED_CART_ENABLED', false),
  isMixedCheckoutEnabled: parseFlag('MIXED_CHECKOUT_ENABLED', false),
  isCodEnabled: parseFlag('COD_ENABLED', false),
  isRiderAvailableIncludeConfirmed: parseFlag('RIDER_AVAILABLE_INCLUDE_CONFIRMED', false),
  riderAvailableMaxRadiusKm: parseFloatFlag('RIDER_AVAILABLE_MAX_RADIUS_KM', 20, { min: 1, max: 200 }),
  isDispatchGeoFallbackEnabled: parseFlag('DISPATCH_GEO_FALLBACK_ENABLED', false),
  codMinPrepaidDeliveredOrders: parseIntFlag('COD_MIN_PREPAID_DELIVERED_ORDERS', 3, { min: 0, max: 20 }),
  codNoShowDisableThreshold: parseIntFlag('COD_NO_SHOW_DISABLE_THRESHOLD', 1, { min: 1, max: 10 }),
  codRequirePhoneVerified: parseFlag('COD_REQUIRE_PHONE_VERIFIED', true),
  codMaxOrderTotalGhs: parseFloatFlag('COD_MAX_ORDER_TOTAL_GHS', 250, { min: 0, max: 10000 }),
  codMaxConcurrentOrders: parseIntFlag('COD_MAX_CONCURRENT_ORDERS', 1, { min: 1, max: 5 }),
  codUpfrontIncludeRainFee: parseFlag('COD_UPFRONT_INCLUDE_RAIN_FEE', false),
  isParcelEnabled: parseFlag('PARCEL_ENABLED', false),
  isParcelScheduledEnabled: parseFlag('PARCEL_SCHEDULED_ENABLED', true),
  isParcelReturnToSenderEnabled: parseFlag('PARCEL_RETURN_TO_SENDER_ENABLED', true),
  isFraudEnabled: parseFlag('FRAUD_ENABLED', true),
  isFraudShadowMode: parseFlag('FRAUD_SHADOW_MODE', true),
  isFraudOutboxWorkerEnabled: parseFlag('FRAUD_OUTBOX_WORKER_ENABLED', true),
  isFraudEventStreamsEnabled: parseFlag('FRAUD_EVENT_STREAMS_ENABLED', true),
  isPaymentWebhookSourceOfTruthEnabled: parseFlag('PAYMENT_WEBHOOK_SOURCE_OF_TRUTH', true),
  isPrepaidFulfillmentGuardEnabled: parseFlag('PREPAID_FULFILLMENT_GUARD', true),

  // ── Rider Partner & Incentive System ──
  isRiderPartnerSystemEnabled: parseFlag('RIDER_PARTNER_SYSTEM_ENABLED', false),
  isRiderPartnerShadowMode: parseFlag('RIDER_PARTNER_SHADOW_MODE', true),
  isRiderIncentivesEnabled: parseFlag('RIDER_INCENTIVES_ENABLED', false),
  isRiderDeliveryAnalyticsEnabled: parseFlag('RIDER_DELIVERY_ANALYTICS_ENABLED', true),
  isRiderMetricsSyncEnabled: parseFlag('RIDER_METRICS_SYNC_ENABLED', true),
  isRiderWithdrawalGuardEnabled: parseFlag('RIDER_WITHDRAWAL_GUARD_ENABLED', true),
};
