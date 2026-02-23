const crypto = require("crypto");
const { sendArkeselSms } = require("./arkesel_service");
const { normalizeGhanaPhone } = require("./otp_service");

const DELIVERY_OTP_SECRET =
  process.env.DELIVERY_OTP_SECRET || process.env.OTP_SECRET || process.env.JWT_SECRET || "grabgo-delivery-otp-secret";
const DELIVERY_OTP_ENCRYPTION_SECRET =
  process.env.DELIVERY_OTP_ENCRYPTION_KEY ||
  process.env.DELIVERY_OTP_SECRET ||
  process.env.OTP_SECRET ||
  process.env.JWT_SECRET ||
  "grabgo-delivery-otp-encryption";
const DELIVERY_OTP_MAX_ATTEMPTS = Number(process.env.DELIVERY_OTP_MAX_ATTEMPTS || 5);
const DELIVERY_OTP_LOCK_SECONDS = Number(process.env.DELIVERY_OTP_LOCK_SECONDS || 15 * 60);
const DELIVERY_OTP_RESEND_COOLDOWN_SECONDS = Number(process.env.DELIVERY_OTP_RESEND_COOLDOWN_SECONDS || 60);
const DELIVERY_OTP_MAX_RESENDS = Number(process.env.DELIVERY_OTP_MAX_RESENDS || 3);

const DELIVERY_CODE_PATTERN = /^\d{4}$/;
const DELIVERY_ENCRYPTION_KEY = crypto
  .createHash("sha256")
  .update(String(DELIVERY_OTP_ENCRYPTION_SECRET))
  .digest();

class DeliveryVerificationError extends Error {
  constructor(message, status = 400, code = "DELIVERY_VERIFICATION_ERROR", meta = {}) {
    super(message);
    this.name = "DeliveryVerificationError";
    this.status = status;
    this.code = code;
    this.meta = meta;
  }
}

const generateDeliveryCode = () => String(Math.floor(1000 + Math.random() * 9000));

const normalizeDeliveryCode = (value) => {
  const raw = String(value || "").trim();
  if (!raw) return "";
  const digits = raw.replace(/\D/g, "");
  return digits.length === 4 ? digits : raw;
};

const isValidDeliveryCode = (value) => DELIVERY_CODE_PATTERN.test(normalizeDeliveryCode(value));

const hashDeliveryCode = (orderId, code) =>
  crypto.createHmac("sha256", DELIVERY_OTP_SECRET).update(`${orderId}:${normalizeDeliveryCode(code)}`).digest("hex");

const encryptDeliveryCode = (code) => {
  const normalized = normalizeDeliveryCode(code);
  if (!DELIVERY_CODE_PATTERN.test(normalized)) {
    throw new DeliveryVerificationError("Delivery code must be exactly 4 digits");
  }

  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", DELIVERY_ENCRYPTION_KEY, iv);
  const encrypted = Buffer.concat([cipher.update(normalized, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();

  return `${iv.toString("base64")}.${tag.toString("base64")}.${encrypted.toString("base64")}`;
};

const decryptDeliveryCode = (payload) => {
  if (!payload) {
    throw new DeliveryVerificationError("Encrypted delivery code is missing");
  }

  const [ivB64, tagB64, ciphertextB64] = String(payload).split(".");
  if (!ivB64 || !tagB64 || !ciphertextB64) {
    throw new DeliveryVerificationError("Encrypted delivery code format is invalid");
  }

  try {
    const iv = Buffer.from(ivB64, "base64");
    const tag = Buffer.from(tagB64, "base64");
    const ciphertext = Buffer.from(ciphertextB64, "base64");

    const decipher = crypto.createDecipheriv("aes-256-gcm", DELIVERY_ENCRYPTION_KEY, iv);
    decipher.setAuthTag(tag);
    const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString("utf8");
    const normalized = normalizeDeliveryCode(decrypted);

    if (!DELIVERY_CODE_PATTERN.test(normalized)) {
      throw new DeliveryVerificationError("Decrypted delivery code is invalid");
    }

    return normalized;
  } catch (error) {
    if (error instanceof DeliveryVerificationError) {
      throw error;
    }
    throw new DeliveryVerificationError("Unable to decrypt delivery code");
  }
};

const isDeliveryCodeLocked = (order) => {
  if (!order?.deliveryCodeLockedUntil) return false;
  return new Date(order.deliveryCodeLockedUntil).getTime() > Date.now();
};

const getDeliveryCodeLockRemainingSeconds = (order) => {
  if (!order?.deliveryCodeLockedUntil) return 0;
  const remainingMs = new Date(order.deliveryCodeLockedUntil).getTime() - Date.now();
  return Math.max(0, Math.ceil(remainingMs / 1000));
};

const getResendAvailability = (order) => {
  if (order?.deliveryCodeVerifiedAt || order?.deliveryVerificationMethod === "authorized_photo") {
    return {
      allowed: false,
      status: 400,
      code: "DELIVERY_VERIFICATION_ALREADY_COMPLETED",
      message: "Delivery verification has already been completed for this order",
    };
  }

  const resendCount = Number(order?.deliveryCodeResendCount || 0);
  if (resendCount >= DELIVERY_OTP_MAX_RESENDS) {
    return {
      allowed: false,
      status: 429,
      code: "DELIVERY_CODE_RESEND_LIMIT_REACHED",
      message: "Delivery code resend limit reached for this order",
    };
  }

  if (order?.deliveryCodeLastSentAt) {
    const elapsedMs = Date.now() - new Date(order.deliveryCodeLastSentAt).getTime();
    const cooldownMs = DELIVERY_OTP_RESEND_COOLDOWN_SECONDS * 1000;
    if (elapsedMs < cooldownMs) {
      return {
        allowed: false,
        status: 429,
        code: "DELIVERY_CODE_RESEND_COOLDOWN",
        message: "Please wait before requesting another delivery code",
        retryAfterSeconds: Math.ceil((cooldownMs - elapsedMs) / 1000),
      };
    }
  }

  return { allowed: true };
};

const buildDeliveryCodeMessage = ({ orderNumber, code, audience = "recipient", recipientName = null }) => {
  if (audience === "customer") {
    return `Your GrabGo delivery code for order #${orderNumber} is ${code}. Share this code with the recipient to complete delivery.`;
  }

  const namePart = recipientName ? `, ${recipientName}` : "";
  return `Your GrabGo delivery${namePart} is arriving soon. Your delivery code is ${code}.`;
};

const normalizeSmsRecipient = (phoneNumber) => {
  const normalized = normalizeGhanaPhone(phoneNumber);
  if (!normalized) return null;
  return process.env.ARKESEL_USE_E164 === "true" ? normalized.e164 : normalized.digits;
};

const sendDeliveryCodeSms = async ({ phoneNumber, orderNumber, code, audience = "recipient", recipientName = null }) => {
  const recipient = normalizeSmsRecipient(phoneNumber);
  if (!recipient) {
    return {
      success: false,
      message: "Invalid recipient phone number",
      code: "INVALID_PHONE",
    };
  }

  const message = buildDeliveryCodeMessage({
    orderNumber,
    code,
    audience,
    recipientName,
  });

  const sendResult = await sendArkeselSms({
    to: recipient,
    message,
  });

  return {
    ...sendResult,
    recipient,
    audience,
  };
};

const verifyDeliveryCodeOrThrow = async ({
  tx,
  order,
  code,
  actorId = null,
  actorRole = "system",
  riderLat = null,
  riderLng = null,
  skipSuccessAudit = false,
}) => {
  if (!order?.id) {
    throw new DeliveryVerificationError("Order not found", 404, "ORDER_NOT_FOUND");
  }

  const currentOrder = await tx.order.findUnique({
    where: { id: order.id },
    select: {
      id: true,
      riderId: true,
      deliveryCodeHash: true,
      deliveryCodeFailedAttempts: true,
      deliveryCodeLockedUntil: true,
      deliveryCodeVerifiedAt: true,
      deliveryVerificationMethod: true,
    },
  });

  if (!currentOrder) {
    throw new DeliveryVerificationError("Order not found", 404, "ORDER_NOT_FOUND");
  }

  if (!currentOrder.deliveryCodeHash) {
    throw new DeliveryVerificationError("Delivery code is not set for this order", 400, "DELIVERY_CODE_NOT_SET");
  }

  if (currentOrder.deliveryCodeVerifiedAt || currentOrder.deliveryVerificationMethod === "authorized_photo") {
    throw new DeliveryVerificationError(
      "Delivery verification has already been completed for this order",
      400,
      "DELIVERY_VERIFICATION_ALREADY_COMPLETED"
    );
  }

  if (isDeliveryCodeLocked(currentOrder)) {
    throw new DeliveryVerificationError(
      "Delivery code verification is temporarily locked. Try again later.",
      429,
      "DELIVERY_CODE_LOCKED",
      { retryAfterSeconds: getDeliveryCodeLockRemainingSeconds(currentOrder) }
    );
  }

  const normalizedCode = normalizeDeliveryCode(code);
  if (!DELIVERY_CODE_PATTERN.test(normalizedCode)) {
    throw new DeliveryVerificationError("Delivery code must be exactly 4 digits", 400, "DELIVERY_CODE_INVALID_FORMAT");
  }

  const codeHash = hashDeliveryCode(currentOrder.id, normalizedCode);
  if (codeHash !== currentOrder.deliveryCodeHash) {
    const failedAttemptUpdate = await tx.order.update({
      where: { id: currentOrder.id },
      data: {
        deliveryCodeFailedAttempts: { increment: 1 },
      },
      select: {
        deliveryCodeFailedAttempts: true,
      },
    });

    const failedAttempts = Number(failedAttemptUpdate.deliveryCodeFailedAttempts || 0);
    const shouldLock = failedAttempts >= DELIVERY_OTP_MAX_ATTEMPTS;
    const lockedUntil = shouldLock ? new Date(Date.now() + DELIVERY_OTP_LOCK_SECONDS * 1000) : null;

    if (shouldLock) {
      await tx.order.update({
        where: { id: currentOrder.id },
        data: {
          deliveryCodeLockedUntil: lockedUntil,
        },
      });
    }

    await tx.orderActionAudit.create({
      data: {
        orderId: currentOrder.id,
        actorId,
        actorRole,
        action: "gift_code_verify_failed",
        metadata: {
          failedAttempts,
          riderLat,
          riderLng,
          lockedUntil: lockedUntil ? lockedUntil.toISOString() : null,
        },
      },
    });

    if (shouldLock) {
      await tx.orderActionAudit.create({
        data: {
          orderId: currentOrder.id,
          actorId,
          actorRole,
          action: "gift_code_lockout",
          metadata: {
            failedAttempts,
            lockedUntil: lockedUntil ? lockedUntil.toISOString() : null,
            riderLat,
            riderLng,
          },
        },
      });
    }

    throw new DeliveryVerificationError(
      shouldLock
        ? "Too many invalid attempts. Verification is temporarily locked."
        : "Invalid delivery code",
      shouldLock ? 429 : 400,
      shouldLock ? "DELIVERY_CODE_LOCKED" : "DELIVERY_CODE_INVALID",
      shouldLock ? { retryAfterSeconds: DELIVERY_OTP_LOCK_SECONDS } : {}
    );
  }

  const verifiedAt = new Date();
  if (!skipSuccessAudit) {
    await tx.orderActionAudit.create({
      data: {
        orderId: currentOrder.id,
        actorId,
        actorRole,
        action: "gift_code_verified",
        metadata: {
          riderLat,
          riderLng,
          verifiedAt: verifiedAt.toISOString(),
        },
      },
    });
  }

  return {
    deliveryCodeFailedAttempts: 0,
    deliveryCodeLockedUntil: null,
    deliveryCodeVerifiedAt: verifiedAt,
    deliveryCodeVerifiedByRiderId: actorRole === "rider" ? actorId : currentOrder.riderId || actorId || null,
    deliveryVerificationMethod: "code",
    deliveryVerificationLat: Number.isFinite(Number(riderLat)) ? Number(riderLat) : null,
    deliveryVerificationLng: Number.isFinite(Number(riderLng)) ? Number(riderLng) : null,
  };
};

module.exports = {
  DeliveryVerificationError,
  DELIVERY_OTP_MAX_ATTEMPTS,
  DELIVERY_OTP_LOCK_SECONDS,
  DELIVERY_OTP_RESEND_COOLDOWN_SECONDS,
  DELIVERY_OTP_MAX_RESENDS,
  generateDeliveryCode,
  isValidDeliveryCode,
  hashDeliveryCode,
  encryptDeliveryCode,
  decryptDeliveryCode,
  isDeliveryCodeLocked,
  getDeliveryCodeLockRemainingSeconds,
  getResendAvailability,
  sendDeliveryCodeSms,
  verifyDeliveryCodeOrThrow,
};
