const {
  RiderAssignmentRouteError,
  createOrderRiderAssignmentHelpers,
} = require("../routes/support/order_rider_assignment_helpers");

describe("order_rider_assignment_helpers", () => {
  let prisma;
  let deps;
  let helpers;

  beforeEach(() => {
    prisma = {
      order: {
        update: jest.fn(),
      },
    };
    deps = {
      shouldTriggerDispatchForOrder: jest.fn(() => true),
      notifyRiderAssignment: jest.fn(),
      notifyOrderStatusChange: jest.fn(),
      getIO: jest.fn(() => ({ io: true })),
    };
    helpers = createOrderRiderAssignmentHelpers({
      prisma,
      ...deps,
    });
  });

  it("throws a typed error when rider assignment is not allowed", () => {
    expect(() =>
      helpers.ensureOrderCanAssignRider({
        order: {
          id: "order-1",
          fulfillmentMode: "delivery",
          paymentStatus: "pending",
          status: "confirmed",
        },
        riderId: "rider-1",
      })
    ).toThrow(RiderAssignmentRouteError);

    try {
      helpers.ensureOrderCanAssignRider({
        order: {
          id: "order-1",
          fulfillmentMode: "delivery",
          paymentStatus: "pending",
          status: "confirmed",
        },
        riderId: "rider-1",
      });
    } catch (error) {
      expect(error.code).toBe("ORDER_PAYMENT_NOT_CONFIRMED");
      expect(error.status).toBe(409);
    }
  });

  it("surfaces scheduled release metadata when assignment is blocked", () => {
    expect(() =>
      helpers.ensureOrderCanAssignRider({
        order: {
          isScheduledOrder: true,
          scheduledReleasedAt: null,
          scheduledForAt: new Date("2026-03-10T12:00:00Z"),
          scheduledReleaseAt: new Date("2026-03-10T11:45:00Z"),
        },
        riderId: "rider-1",
      })
    ).toThrow(RiderAssignmentRouteError);

    try {
      helpers.ensureOrderCanAssignRider({
        order: {
          isScheduledOrder: true,
          scheduledReleasedAt: null,
          scheduledForAt: new Date("2026-03-10T12:00:00Z"),
          scheduledReleaseAt: new Date("2026-03-10T11:45:00Z"),
        },
        riderId: "rider-1",
      });
    } catch (error) {
      expect(error.code).toBe("SCHEDULED_ORDER_NOT_RELEASED");
      expect(error.meta).toEqual({
        scheduledForAt: "2026-03-10T12:00:00.000Z",
        scheduledReleaseAt: "2026-03-10T11:45:00.000Z",
      });
    }
  });

  it("assigns rider, promotes ready orders to picked_up, and notifies both rider and customer", async () => {
    prisma.order.update.mockResolvedValue({
      id: "order-2",
      status: "picked_up",
      rider: { username: "Yaw" },
      customer: { username: "Ama" },
    });

    const updatedOrder = await helpers.assignRiderAndNotify({
      orderId: "order-2",
      order: { status: "ready" },
      riderId: "rider-2",
      rider: { username: "Yaw" },
    });

    expect(prisma.order.update).toHaveBeenCalledWith({
      where: { id: "order-2" },
      data: { riderId: "rider-2", status: "picked_up" },
      include: {
        rider: { select: { username: true, email: true, phone: true } },
        customer: { select: { username: true, email: true, phone: true } },
      },
    });
    expect(deps.notifyRiderAssignment).toHaveBeenCalledWith("rider-2", updatedOrder);
    expect(deps.notifyOrderStatusChange).toHaveBeenCalledWith(
      updatedOrder,
      "picked_up",
      "Yaw is picking up your order!",
      { io: true }
    );
  });

  it("notifies customer with assigned message for non-ready orders", async () => {
    prisma.order.update.mockResolvedValue({
      id: "order-3",
      status: "confirmed",
      rider: { username: "Kojo" },
      customer: { username: "Esi" },
    });

    await helpers.assignRiderAndNotify({
      orderId: "order-3",
      order: { status: "confirmed" },
      riderId: "rider-3",
      rider: { username: "Kojo" },
    });

    expect(deps.notifyOrderStatusChange).toHaveBeenCalledWith(
      expect.objectContaining({ id: "order-3" }),
      "confirmed",
      "Kojo has been assigned to your order.",
      { io: true }
    );
  });
});
