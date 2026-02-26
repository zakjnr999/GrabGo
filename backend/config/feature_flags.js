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
  codMinPrepaidDeliveredOrders: parseIntFlag('COD_MIN_PREPAID_DELIVERED_ORDERS', 3, { min: 0, max: 20 }),
  codNoShowDisableThreshold: parseIntFlag('COD_NO_SHOW_DISABLE_THRESHOLD', 1, { min: 1, max: 10 }),
  codRequirePhoneVerified: parseFlag('COD_REQUIRE_PHONE_VERIFIED', true),
  codMaxOrderTotalGhs: parseFloatFlag('COD_MAX_ORDER_TOTAL_GHS', 250, { min: 0, max: 10000 }),
  codMaxConcurrentOrders: parseIntFlag('COD_MAX_CONCURRENT_ORDERS', 1, { min: 1, max: 5 }),
  codUpfrontIncludeRainFee: parseFlag('COD_UPFRONT_INCLUDE_RAIN_FEE', false),
};
