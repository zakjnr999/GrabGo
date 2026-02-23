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

const defaultPickupEnabled = !isProduction;

module.exports = {
  isPickupCheckoutEnabled: parseFlag('PICKUP_CHECKOUT_ENABLED', defaultPickupEnabled),
  isPickupVendorOpsEnabled: parseFlag('PICKUP_VENDOR_OPS_ENABLED', defaultPickupEnabled),
  isPickupOtpEnabled: parseFlag('PICKUP_OTP_ENABLED', defaultPickupEnabled),
  isPickupReadyExpiryEnabled: parseFlag('PICKUP_READY_EXPIRY_ENABLED', defaultPickupEnabled),
  isGiftOrdersEnabled: parseFlag('GIFT_ORDERS_ENABLED', false),
  isScheduledOrdersEnabled: parseFlag('SCHEDULED_ORDERS_ENABLED', false),
};
