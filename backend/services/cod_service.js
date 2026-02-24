class CodPolicyError extends Error {
  constructor(message, status = 400, code = "COD_POLICY_ERROR", meta = {}) {
    super(message);
    this.name = "CodPolicyError";
    this.status = status;
    this.code = code;
    this.meta = meta;
  }
}

const COD_NO_SHOW_REASON = "cod_no_show_confirmed";
const COD_NO_SHOW_REASON_ALIASES = new Set([
  COD_NO_SHOW_REASON,
  "cod_no_show",
  "cod_noshow",
  "customer_unreachable_cod",
  "customer_no_show",
]);

const ACTIVE_ORDER_STATUSES = new Set([
  "pending",
  "confirmed",
  "preparing",
  "ready",
  "picked_up",
  "on_the_way",
]);

const normalizeReason = (reason) =>
  String(reason || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "_");

const toMoney = (value) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 0;
  return Math.round(parsed * 100) / 100;
};

const isCodNoShowReason = (reason) => COD_NO_SHOW_REASON_ALIASES.has(normalizeReason(reason));

const getCodExternalPaymentAmount = (orderLike, { includeRainFee = false } = {}) => {
  const deliveryFee = Number(orderLike?.deliveryFee || 0);
  const rainFee = includeRainFee ? Number(orderLike?.rainFee || 0) : 0;
  return toMoney(Math.max(0, deliveryFee + rainFee));
};

const getCodRemainingCashAmount = (orderLike, { includeRainFee = false } = {}) => {
  const totalAmount = Number(orderLike?.totalAmount || 0);
  const upfront = getCodExternalPaymentAmount(orderLike, { includeRainFee });
  return toMoney(Math.max(0, totalAmount - upfront));
};

const validateCodNoShowEvidence = (rawEvidence) => {
  const evidence = rawEvidence && typeof rawEvidence === "object" ? rawEvidence : {};
  const photoUrl = String(evidence.photoUrl || "").trim();
  const contactAttempts = Number(evidence.contactAttempts);
  const waitedMinutes = Number(evidence.waitedMinutes);
  const riderLat = evidence.riderLat;
  const riderLng = evidence.riderLng;

  const errors = [];
  if (!photoUrl) {
    errors.push("noShowEvidence.photoUrl is required");
  }
  if (!Number.isInteger(contactAttempts) || contactAttempts < 2) {
    errors.push("noShowEvidence.contactAttempts must be at least 2");
  }
  if (!Number.isFinite(waitedMinutes) || waitedMinutes < 5) {
    errors.push("noShowEvidence.waitedMinutes must be at least 5");
  }
  if (!Number.isFinite(Number(riderLat)) || !Number.isFinite(Number(riderLng))) {
    errors.push("noShowEvidence.riderLat and noShowEvidence.riderLng are required");
  }

  if (errors.length > 0) {
    throw new CodPolicyError(
      "No-show cancellation evidence is incomplete",
      400,
      "COD_NO_SHOW_EVIDENCE_REQUIRED",
      { errors }
    );
  }

  return {
    photoUrl,
    contactAttempts,
    waitedMinutes,
    riderLat: Number(riderLat),
    riderLng: Number(riderLng),
    notes: evidence.notes ? String(evidence.notes).trim() : null,
    confirmedAt: new Date().toISOString(),
  };
};

const evaluateCodEligibility = async ({
  prisma,
  customerId,
  minPrepaidDeliveredOrders = 3,
  noShowDisableThreshold = 1,
  requirePhoneVerified = true,
  maxConcurrentCodOrders = 1,
}) => {
  const [customer, deliveredPrepaidOrders, confirmedNoShows, activeCodOrders] = await Promise.all([
    prisma.user.findUnique({
      where: { id: customerId },
      select: {
        id: true,
        isActive: true,
        phone: true,
        isPhoneVerified: true,
      },
    }),
    prisma.order.count({
      where: {
        customerId,
        status: "delivered",
        paymentMethod: { not: "cash" },
      },
    }),
    prisma.order.count({
      where: {
        customerId,
        paymentMethod: "cash",
        status: "cancelled",
        cancellationReason: COD_NO_SHOW_REASON,
      },
    }),
    prisma.order.count({
      where: {
        customerId,
        paymentMethod: "cash",
        status: { in: Array.from(ACTIVE_ORDER_STATUSES) },
      },
    }),
  ]);

  if (!customer || customer.isActive === false) {
    return {
      eligible: false,
      status: 403,
      code: "COD_ACCOUNT_INACTIVE",
      message: "Cash on delivery is unavailable for this account",
      metrics: { deliveredPrepaidOrders, confirmedNoShows, activeCodOrders },
    };
  }

  if (!customer.phone) {
    return {
      eligible: false,
      status: 403,
      code: "COD_PHONE_REQUIRED",
      message: "Add a phone number before using cash on delivery",
      metrics: { deliveredPrepaidOrders, confirmedNoShows, activeCodOrders },
    };
  }

  if (requirePhoneVerified && customer.isPhoneVerified !== true) {
    return {
      eligible: false,
      status: 403,
      code: "COD_PHONE_NOT_VERIFIED",
      message: "Verify your phone number before using cash on delivery",
      metrics: { deliveredPrepaidOrders, confirmedNoShows, activeCodOrders },
    };
  }

  if (deliveredPrepaidOrders < minPrepaidDeliveredOrders) {
    return {
      eligible: false,
      status: 403,
      code: "COD_TRUST_THRESHOLD_NOT_MET",
      message: `Complete ${minPrepaidDeliveredOrders} prepaid orders to unlock cash on delivery`,
      metrics: { deliveredPrepaidOrders, minPrepaidDeliveredOrders, confirmedNoShows, activeCodOrders },
    };
  }

  if (confirmedNoShows >= noShowDisableThreshold) {
    return {
      eligible: false,
      status: 403,
      code: "COD_DISABLED_NO_SHOW",
      message: "Cash on delivery has been disabled due to prior no-show activity",
      metrics: { deliveredPrepaidOrders, confirmedNoShows, noShowDisableThreshold, activeCodOrders },
    };
  }

  if (activeCodOrders >= maxConcurrentCodOrders) {
    return {
      eligible: false,
      status: 409,
      code: "COD_ACTIVE_ORDER_EXISTS",
      message: "Complete your active cash on delivery order first",
      metrics: { deliveredPrepaidOrders, confirmedNoShows, activeCodOrders, maxConcurrentCodOrders },
    };
  }

  return {
    eligible: true,
    status: 200,
    code: "COD_ELIGIBLE",
    message: "Cash on delivery is available",
    metrics: { deliveredPrepaidOrders, confirmedNoShows, activeCodOrders },
  };
};

const isCodDispatchAllowedStatus = (status) => status === "preparing" || status === "ready";

module.exports = {
  CodPolicyError,
  COD_NO_SHOW_REASON,
  isCodNoShowReason,
  getCodExternalPaymentAmount,
  getCodRemainingCashAmount,
  validateCodNoShowEvidence,
  evaluateCodEligibility,
  isCodDispatchAllowedStatus,
};
