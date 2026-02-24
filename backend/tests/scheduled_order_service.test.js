const {
  normalizeDeliveryTimeType,
  validateScheduledDeliveryRequest,
  validateScheduledVendorAvailability,
  ScheduledOrderError,
  SCHEDULED_ORDER_MIN_LEAD_MINUTES,
  SCHEDULED_ORDER_RELEASE_LEAD_MINUTES,
  SCHEDULED_ORDER_SLOT_MINUTES,
} = require("../services/scheduled_order_service");

describe("scheduled_order_service", () => {
  it("defaults delivery time type to asap", () => {
    expect(normalizeDeliveryTimeType(undefined)).toBe("asap");
    expect(normalizeDeliveryTimeType("ASAP")).toBe("asap");
  });

  it("accepts scheduled type", () => {
    expect(normalizeDeliveryTimeType("scheduled")).toBe("scheduled");
  });

  it("returns asap metadata when not scheduled", () => {
    const result = validateScheduledDeliveryRequest({
      deliveryTimeType: "asap",
      fulfillmentMode: "delivery",
      featureEnabled: true,
      now: new Date("2026-01-01T10:00:00.000Z"),
    });

    expect(result.isScheduledOrder).toBe(false);
    expect(result.scheduledForAt).toBeNull();
  });

  it("rejects scheduled request for pickup mode", () => {
    expect(() =>
      validateScheduledDeliveryRequest({
        deliveryTimeType: "scheduled",
        scheduledForAt: "2026-01-01T12:00:00.000Z",
        fulfillmentMode: "pickup",
        featureEnabled: true,
        now: new Date("2026-01-01T10:00:00.000Z"),
      })
    ).toThrow(ScheduledOrderError);
  });

  it("rejects scheduled request when too soon", () => {
    const now = new Date("2026-01-01T10:00:00.000Z");
    const tooSoon = new Date(now.getTime() + (SCHEDULED_ORDER_MIN_LEAD_MINUTES - 1) * 60 * 1000).toISOString();

    expect(() =>
      validateScheduledDeliveryRequest({
        deliveryTimeType: "scheduled",
        scheduledForAt: tooSoon,
        fulfillmentMode: "delivery",
        featureEnabled: true,
        now,
      })
    ).toThrow(ScheduledOrderError);
  });

  it("builds scheduled metadata for valid scheduled request", () => {
    const now = new Date("2026-01-01T10:00:00.000Z");
    const scheduledForAt = new Date(now.getTime() + (SCHEDULED_ORDER_MIN_LEAD_MINUTES + 30) * 60 * 1000);

    const result = validateScheduledDeliveryRequest({
      deliveryTimeType: "scheduled",
      scheduledForAt: scheduledForAt.toISOString(),
      fulfillmentMode: "delivery",
      featureEnabled: true,
      now,
    });

    expect(result.isScheduledOrder).toBe(true);
    expect(result.scheduledForAt.toISOString()).toBe(scheduledForAt.toISOString());

    const expectedReleaseAt = new Date(scheduledForAt.getTime() - SCHEDULED_ORDER_RELEASE_LEAD_MINUTES * 60 * 1000);
    const expectedWindowEnd = new Date(scheduledForAt.getTime() + SCHEDULED_ORDER_SLOT_MINUTES * 60 * 1000);

    expect(result.scheduledReleaseAt.toISOString()).toBe(expectedReleaseAt.toISOString());
    expect(result.scheduledWindowEndAt.toISOString()).toBe(expectedWindowEnd.toISOString());
  });

  it("rejects scheduled slot when vendor is manually closed", () => {
    expect(() =>
      validateScheduledVendorAvailability({
        isOpen: false,
        openingHours: [
          { dayOfWeek: 4, openTime: "09:00", closeTime: "20:00", isClosed: false },
        ],
        scheduledWindowStartAt: "2026-01-01T12:00:00.000Z",
        scheduledWindowEndAt: "2026-01-01T12:30:00.000Z",
        vendorType: "food",
        vendorName: "Test Kitchen",
      })
    ).toThrow(ScheduledOrderError);
  });

  it("rejects scheduled slot outside configured opening hours", () => {
    expect(() =>
      validateScheduledVendorAvailability({
        isOpen: true,
        openingHours: [
          { dayOfWeek: 4, openTime: "09:00", closeTime: "17:00", isClosed: false },
        ],
        scheduledWindowStartAt: "2026-01-01T18:00:00.000Z",
        scheduledWindowEndAt: "2026-01-01T18:30:00.000Z",
        vendorType: "food",
        vendorName: "Test Kitchen",
      })
    ).toThrow(ScheduledOrderError);
  });

  it("rejects scheduled slot that extends past close time", () => {
    expect(() =>
      validateScheduledVendorAvailability({
        isOpen: true,
        openingHours: [
          { dayOfWeek: 4, openTime: "09:00", closeTime: "10:00", isClosed: false },
        ],
        scheduledWindowStartAt: "2026-01-01T09:45:00.000Z",
        scheduledWindowEndAt: "2026-01-01T10:15:00.000Z",
        vendorType: "food",
        vendorName: "Test Kitchen",
      })
    ).toThrow(ScheduledOrderError);
  });

  it("allows scheduled slot inside configured opening hours", () => {
    expect(() =>
      validateScheduledVendorAvailability({
        isOpen: true,
        openingHours: [
          { dayOfWeek: 4, openTime: "09:00", closeTime: "17:00", isClosed: false },
        ],
        scheduledWindowStartAt: "2026-01-01T12:00:00.000Z",
        scheduledWindowEndAt: "2026-01-01T12:30:00.000Z",
        vendorType: "food",
        vendorName: "Test Kitchen",
      })
    ).not.toThrow();
  });

  it("allows overnight schedule slots when previous day spills past midnight", () => {
    expect(() =>
      validateScheduledVendorAvailability({
        isOpen: true,
        openingHours: [
          { dayOfWeek: 4, openTime: "22:00", closeTime: "02:00", isClosed: false },
        ],
        scheduledWindowStartAt: "2026-01-02T00:30:00.000Z",
        scheduledWindowEndAt: "2026-01-02T01:00:00.000Z",
        vendorType: "food",
        vendorName: "Late Night Kitchen",
      })
    ).not.toThrow();
  });

  it("allows scheduled slot when vendor is closed now but allowClosedNow is true", () => {
    expect(() =>
      validateScheduledVendorAvailability({
        isOpen: false,
        allowClosedNow: true,
        openingHours: [
          { dayOfWeek: 4, openTime: "09:00", closeTime: "17:00", isClosed: false },
        ],
        scheduledWindowStartAt: "2026-01-01T12:00:00.000Z",
        scheduledWindowEndAt: "2026-01-01T12:30:00.000Z",
        vendorType: "food",
        vendorName: "Test Kitchen",
      })
    ).not.toThrow();
  });
});
