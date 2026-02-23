const parsePositiveIntEnv = (name, fallback, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const raw = process.env[name];
  const parsed = Number.parseInt(String(raw), 10);

  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return fallback;
  }

  return parsed;
};

const SCHEDULED_ORDER_MIN_LEAD_MINUTES = parsePositiveIntEnv("SCHEDULED_ORDER_MIN_LEAD_MINUTES", 45, {
  min: 1,
  max: 24 * 60,
});

const configuredReleaseLeadMinutes = parsePositiveIntEnv("SCHEDULED_ORDER_RELEASE_LEAD_MINUTES", 30, {
  min: 0,
  max: 24 * 60,
});

const SCHEDULED_ORDER_RELEASE_LEAD_MINUTES = Math.min(
  configuredReleaseLeadMinutes,
  SCHEDULED_ORDER_MIN_LEAD_MINUTES
);

const SCHEDULED_ORDER_MAX_HORIZON_DAYS = parsePositiveIntEnv("SCHEDULED_ORDER_MAX_HORIZON_DAYS", 7, {
  min: 1,
  max: 30,
});

const SCHEDULED_ORDER_SLOT_MINUTES = parsePositiveIntEnv("SCHEDULED_ORDER_SLOT_MINUTES", 30, {
  min: 5,
  max: 4 * 60,
});

class ScheduledOrderError extends Error {
  constructor(message, status = 400, code = "SCHEDULED_ORDER_ERROR", meta = {}) {
    super(message);
    this.name = "ScheduledOrderError";
    this.status = status;
    this.code = code;
    this.meta = meta;
  }
}

const normalizeDeliveryTimeType = (value) => {
  const normalized = String(value || "asap").trim().toLowerCase();
  return normalized === "scheduled" ? "scheduled" : "asap";
};

const parseScheduledForAt = (value) => {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const validateScheduledDeliveryRequest = ({
  deliveryTimeType,
  scheduledForAt,
  fulfillmentMode,
  featureEnabled,
  now = new Date(),
}) => {
  const normalizedType = normalizeDeliveryTimeType(deliveryTimeType);

  if (normalizedType !== "scheduled") {
    return {
      deliveryTimeType: "asap",
      isScheduledOrder: false,
      scheduledForAt: null,
      scheduledWindowStartAt: null,
      scheduledWindowEndAt: null,
      scheduledReleaseAt: null,
    };
  }

  if (!featureEnabled) {
    throw new ScheduledOrderError(
      "Scheduled orders are temporarily unavailable",
      403,
      "SCHEDULED_ORDERS_DISABLED"
    );
  }

  if (String(fulfillmentMode || "").toLowerCase() !== "delivery") {
    throw new ScheduledOrderError(
      "Scheduled orders are only supported for delivery orders",
      400,
      "SCHEDULED_ORDER_DELIVERY_ONLY"
    );
  }

  const scheduledForAtDate = parseScheduledForAt(scheduledForAt);
  if (!scheduledForAtDate) {
    throw new ScheduledOrderError(
      "scheduledForAt is required and must be a valid ISO datetime for scheduled orders",
      400,
      "SCHEDULED_ORDER_DATETIME_REQUIRED"
    );
  }

  const nowMs = now.getTime();
  const scheduledForAtMs = scheduledForAtDate.getTime();
  const minLeadMs = SCHEDULED_ORDER_MIN_LEAD_MINUTES * 60 * 1000;
  const maxHorizonMs = SCHEDULED_ORDER_MAX_HORIZON_DAYS * 24 * 60 * 60 * 1000;
  const leadMs = scheduledForAtMs - nowMs;

  if (leadMs < minLeadMs) {
    throw new ScheduledOrderError(
      `Scheduled time must be at least ${SCHEDULED_ORDER_MIN_LEAD_MINUTES} minutes from now`,
      400,
      "SCHEDULED_ORDER_TOO_SOON",
      { minLeadMinutes: SCHEDULED_ORDER_MIN_LEAD_MINUTES }
    );
  }

  if (leadMs > maxHorizonMs) {
    throw new ScheduledOrderError(
      `Scheduled time cannot be more than ${SCHEDULED_ORDER_MAX_HORIZON_DAYS} days ahead`,
      400,
      "SCHEDULED_ORDER_TOO_FAR",
      { maxHorizonDays: SCHEDULED_ORDER_MAX_HORIZON_DAYS }
    );
  }

  const scheduledWindowStartAt = new Date(scheduledForAtMs);
  const scheduledWindowEndAt = new Date(scheduledForAtMs + SCHEDULED_ORDER_SLOT_MINUTES * 60 * 1000);
  const scheduledReleaseAt = new Date(scheduledForAtMs - SCHEDULED_ORDER_RELEASE_LEAD_MINUTES * 60 * 1000);

  return {
    deliveryTimeType: "scheduled",
    isScheduledOrder: true,
    scheduledForAt: scheduledForAtDate,
    scheduledWindowStartAt,
    scheduledWindowEndAt,
    scheduledReleaseAt,
  };
};

const isScheduledOrderReleased = (order) => {
  if (!order?.isScheduledOrder) return true;
  return !!order.scheduledReleasedAt;
};

module.exports = {
  ScheduledOrderError,
  SCHEDULED_ORDER_MIN_LEAD_MINUTES,
  SCHEDULED_ORDER_RELEASE_LEAD_MINUTES,
  SCHEDULED_ORDER_MAX_HORIZON_DAYS,
  SCHEDULED_ORDER_SLOT_MINUTES,
  normalizeDeliveryTimeType,
  parseScheduledForAt,
  validateScheduledDeliveryRequest,
  isScheduledOrderReleased,
};
