class RiderAssignmentRouteError extends Error {
  constructor(message, status = 400, code = null, meta = null) {
    super(message);
    this.name = "RiderAssignmentRouteError";
    this.status = status;
    this.code = code;
    this.meta = meta;
  }
}

const createOrderRiderAssignmentHelpers = ({
  prisma,
  shouldTriggerDispatchForOrder,
  notifyRiderAssignment,
  notifyOrderStatusChange,
  getIO,
}) => {
  const ensureOrderCanAssignRider = ({ order, riderId }) => {
    if (!order) {
      throw new RiderAssignmentRouteError("Order not found", 404);
    }

    if (order.isScheduledOrder && !order.scheduledReleasedAt) {
      throw new RiderAssignmentRouteError(
        "Scheduled order is not yet released for rider assignment",
        409,
        "SCHEDULED_ORDER_NOT_RELEASED",
        {
          scheduledForAt: order.scheduledForAt
            ? new Date(order.scheduledForAt).toISOString()
            : null,
          scheduledReleaseAt: order.scheduledReleaseAt
            ? new Date(order.scheduledReleaseAt).toISOString()
            : null,
        }
      );
    }

    if (!riderId) {
      throw new RiderAssignmentRouteError("riderId is required", 400);
    }

    if (order.fulfillmentMode === "pickup") {
      throw new RiderAssignmentRouteError(
        "Pickup orders are not eligible for rider assignment",
        400
      );
    }

    if (!["paid", "successful"].includes(order.paymentStatus)) {
      throw new RiderAssignmentRouteError(
        "Order payment is not confirmed yet",
        409,
        "ORDER_PAYMENT_NOT_CONFIRMED"
      );
    }

    if (!shouldTriggerDispatchForOrder(order, order.status)) {
      throw new RiderAssignmentRouteError(
        "Order is not in a rider-assignable state",
        409,
        "ORDER_STATUS_NOT_DISPATCHABLE"
      );
    }
  };

  const assignRiderAndNotify = async ({ orderId, order, riderId, rider }) => {
    const statusUpdate = order.status === "ready" ? { status: "picked_up" } : {};

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        riderId,
        ...statusUpdate,
      },
      include: {
        rider: { select: { username: true, email: true, phone: true } },
        customer: { select: { username: true, email: true, phone: true } },
      },
    });

    notifyRiderAssignment(riderId, updatedOrder);

    const io = getIO();
    const statusToNotify = updatedOrder.status === "picked_up" ? "picked_up" : updatedOrder.status;
    const customMsg = updatedOrder.status === "picked_up"
      ? `${rider.username} is picking up your order!`
      : `${rider.username} has been assigned to your order.`;

    notifyOrderStatusChange(updatedOrder, statusToNotify, customMsg, io);

    return updatedOrder;
  };

  return {
    ensureOrderCanAssignRider,
    assignRiderAndNotify,
  };
};

module.exports = {
  RiderAssignmentRouteError,
  createOrderRiderAssignmentHelpers,
};
