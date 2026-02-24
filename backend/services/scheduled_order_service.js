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

const parseTimeToMinutes = (value) => {
  if (typeof value !== "string") return null;
  const match = value.trim().match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
  if (!match) return null;

  const hour = Number.parseInt(match[1], 10);
  const minute = Number.parseInt(match[2], 10);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return hour * 60 + minute;
};

const getOpeningHoursForDay = (openingHours, dayOfWeek) => {
  if (!Array.isArray(openingHours)) return null;
  return openingHours.find((entry) => Number(entry?.dayOfWeek) === dayOfWeek) || null;
};

const isTimeWithinWindow = (minuteOfDay, openMinute, closeMinute) => {
  // Equal open/close means full-day availability.
  if (openMinute === closeMinute) return true;
  if (closeMinute > openMinute) {
    return minuteOfDay >= openMinute && minuteOfDay < closeMinute;
  }

  // Overnight window (e.g. 22:00 -> 02:00).
  return minuteOfDay >= openMinute || minuteOfDay < closeMinute;
};

const isOpenAtWithOpeningHours = (openingHours, atDate) => {
  if (!Array.isArray(openingHours) || openingHours.length === 0) return false;
  if (!(atDate instanceof Date) || Number.isNaN(atDate.getTime())) return false;

  const dayOfWeek = atDate.getDay();
  const minuteOfDay = atDate.getHours() * 60 + atDate.getMinutes();
  const todayHours = getOpeningHoursForDay(openingHours, dayOfWeek);

  if (todayHours && todayHours.isClosed !== true) {
    const todayOpenMinute = parseTimeToMinutes(todayHours.openTime);
    const todayCloseMinute = parseTimeToMinutes(todayHours.closeTime);
    if (
      todayOpenMinute !== null &&
      todayCloseMinute !== null &&
      isTimeWithinWindow(minuteOfDay, todayOpenMinute, todayCloseMinute)
    ) {
      return true;
    }
  }

  // Also check if previous day spills overnight into current day.
  const previousDay = (dayOfWeek + 6) % 7;
  const previousDayHours = getOpeningHoursForDay(openingHours, previousDay);
  if (!previousDayHours || previousDayHours.isClosed === true) return false;

  const prevOpenMinute = parseTimeToMinutes(previousDayHours.openTime);
  const prevCloseMinute = parseTimeToMinutes(previousDayHours.closeTime);
  if (prevOpenMinute === null || prevCloseMinute === null) return false;

  // Previous-day window is overnight only when close < open.
  if (prevCloseMinute >= prevOpenMinute) return false;
  return minuteOfDay < prevCloseMinute;
};

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

const validateScheduledVendorAvailability = ({
  isOpen,
  is24Hours,
  openingHours,
  scheduledWindowStartAt,
  scheduledWindowEndAt,
  vendorType,
  vendorName,
  allowClosedNow = false,
}) => {
  if (!scheduledWindowStartAt) return;

  const startAt = new Date(scheduledWindowStartAt);
  if (Number.isNaN(startAt.getTime())) {
    throw new ScheduledOrderError(
      "Scheduled delivery window is invalid",
      400,
      "SCHEDULED_ORDER_WINDOW_INVALID"
    );
  }

  const rawEndAt = scheduledWindowEndAt ? new Date(scheduledWindowEndAt) : null;
  const endAt = rawEndAt && !Number.isNaN(rawEndAt.getTime()) ? rawEndAt : null;

  if (isOpen === false && !allowClosedNow) {
    throw new ScheduledOrderError(
      `${vendorName || "Vendor"} is not accepting scheduled orders at the selected time`,
      400,
      "SCHEDULED_ORDER_VENDOR_CLOSED",
      {
        vendorType: vendorType || null,
        vendorName: vendorName || null,
        scheduledWindowStartAt: startAt.toISOString(),
        scheduledWindowEndAt: endAt ? endAt.toISOString() : null,
      }
    );
  }

  if (is24Hours === true) {
    return;
  }

  if (!Array.isArray(openingHours) || openingHours.length === 0) {
    // Without opening-hours records we fall back to the manual isOpen/is24Hours flags.
    if (isOpen === false) {
      throw new ScheduledOrderError(
        `${vendorName || "Vendor"} is closed during the selected delivery window`,
        400,
        "SCHEDULED_ORDER_VENDOR_CLOSED",
        {
          vendorType: vendorType || null,
          vendorName: vendorName || null,
          scheduledWindowStartAt: startAt.toISOString(),
          scheduledWindowEndAt: endAt ? endAt.toISOString() : null,
        }
      );
    }
    return;
  }

  const effectiveEndCheckAt =
    endAt && endAt.getTime() > startAt.getTime() ? new Date(endAt.getTime() - 60 * 1000) : startAt;
  const isStartInsideHours = isOpenAtWithOpeningHours(openingHours, startAt);
  const isEndInsideHours = isOpenAtWithOpeningHours(openingHours, effectiveEndCheckAt);

  if (isStartInsideHours && isEndInsideHours) {
    return;
  }

  throw new ScheduledOrderError(
    `${vendorName || "Vendor"} is closed during the selected delivery window`,
    400,
    "SCHEDULED_ORDER_VENDOR_CLOSED",
    {
      vendorType: vendorType || null,
      vendorName: vendorName || null,
      scheduledWindowStartAt: startAt.toISOString(),
      scheduledWindowEndAt: endAt ? endAt.toISOString() : null,
    }
  );
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
  parseTimeToMinutes,
  isOpenAtWithOpeningHours,
  normalizeDeliveryTimeType,
  parseScheduledForAt,
  validateScheduledDeliveryRequest,
  validateScheduledVendorAvailability,
  isScheduledOrderReleased,
};
