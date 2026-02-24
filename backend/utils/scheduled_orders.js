const SCHEDULED_ENABLED_FEATURE_KEYS = new Set([
  "scheduled_orders",
  "scheduled_orders_enabled",
  "accept_scheduled_orders",
  "accept-scheduled-orders",
  "scheduledorders",
]);

const SCHEDULED_DISABLED_FEATURE_KEYS = new Set([
  "scheduled_orders_disabled",
  "disable_scheduled_orders",
  "scheduled_orders_off",
  "disable-scheduled-orders",
  "scheduledordersoff",
]);

const normalizeFeature = (value) => String(value || "").trim().toLowerCase();

const isVendorAcceptingScheduledOrders = (vendor) => {
  if (!vendor || typeof vendor !== "object") return false;
  if (vendor.isDeleted === true) return false;
  if (vendor.isAcceptingOrders === false) return false;

  const features = Array.isArray(vendor.features) ? vendor.features.map(normalizeFeature) : [];
  if (features.some((feature) => SCHEDULED_DISABLED_FEATURE_KEYS.has(feature))) {
    return false;
  }
  if (features.some((feature) => SCHEDULED_ENABLED_FEATURE_KEYS.has(feature))) {
    return true;
  }

  // Backward-compatible default:
  // vendors accept scheduled orders unless explicitly disabled.
  return true;
};

module.exports = {
  isVendorAcceptingScheduledOrders,
};
