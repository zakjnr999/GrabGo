const crypto = require('crypto');
const cache = require('../utils/cache');
const { generateOTP } = require('../utils/emailService');
const { sendArkeselSms, sendArkeselWhatsapp } = require('./arkesel_service');

const OTP_CONFIG = {
  ttlSeconds: Number(process.env.OTP_TTL_SECONDS || 600),
  resendCooldownSeconds: Number(process.env.OTP_RESEND_COOLDOWN_SECONDS || 60),
  maxSendPerHour: Number(process.env.OTP_MAX_SEND_PER_HOUR || 5),
  maxVerifyAttempts: Number(process.env.OTP_MAX_VERIFY_ATTEMPTS || 5),
  lockoutSeconds: Number(process.env.OTP_LOCKOUT_SECONDS || 900),
  verifiedTokenTtlSeconds: Number(process.env.OTP_VERIFIED_TTL_SECONDS || 1800),
  sendWindowSeconds: 3600,
};

const OTP_CHANNELS = new Set(['sms', 'whatsapp']);

const normalizeGhanaPhone = (input) => {
  if (!input) return null;
  const digitsOnly = String(input).replace(/\D/g, '');

  let normalized = digitsOnly;
  if (normalized.startsWith('0')) {
    normalized = `233${normalized.slice(1)}`;
  } else if (normalized.length === 9) {
    normalized = `233${normalized}`;
  }

  if (!normalized.startsWith('233') || normalized.length !== 12) {
    return null;
  }

  return {
    e164: `+${normalized}`,
    digits: normalized,
  };
};

const hashOtp = (otp, phoneE164) => {
  const secret = process.env.OTP_SECRET || process.env.JWT_SECRET || 'grabgo-otp-secret';
  return crypto.createHmac('sha256', secret).update(`${phoneE164}:${otp}`).digest('hex');
};

const getKey = (type, phoneDigits) => `grabgo:otp:${type}:${phoneDigits}`;

const getCounter = async (key) => {
  const value = await cache.get(key);
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return Number(value) || 0;
  if (typeof value === 'object' && value.count !== undefined) return Number(value.count) || 0;
  return 0;
};

const setCounter = async (key, count, ttlSeconds) => {
  return cache.set(key, count, ttlSeconds);
};

const incrementCounter = async (key, ttlSeconds) => {
  const current = await getCounter(key);
  const next = current + 1;
  await setCounter(key, next, ttlSeconds);
  return next;
};

const sendViaGateway = async ({ channel, to, message }) => {
  if (channel === 'whatsapp') {
    return sendArkeselWhatsapp({ to, message });
  }
  return sendArkeselSms({ to, message });
};

const requestPhoneOtp = async ({ phoneNumber, userId, channel = 'sms' }) => {
  const normalized = normalizeGhanaPhone(phoneNumber);
  if (!normalized) {
    return { success: false, message: 'Invalid Ghana phone number.' };
  }

  const resolvedChannel = OTP_CHANNELS.has(channel) ? channel : 'sms';
  const lockKey = getKey('lock', normalized.digits);
  const isLocked = await cache.get(lockKey);
  if (isLocked) {
    return { success: false, message: 'Too many attempts. Please try again later.' };
  }

  const sendCountKey = getKey('send', normalized.digits);
  const sendCount = await getCounter(sendCountKey);
  if (sendCount >= OTP_CONFIG.maxSendPerHour) {
    return { success: false, message: 'Too many OTP requests. Please try again later.' };
  }

  const cooldownKey = getKey('cooldown', normalized.digits);
  const cooldown = await cache.get(cooldownKey);
  if (cooldown) {
    return { success: false, message: 'Please wait before requesting another OTP.' };
  }

  const otp = generateOTP();
  const otpKey = getKey('code', normalized.digits);
  const otpPayload = {
    hash: hashOtp(otp, normalized.e164),
    userId: userId || null,
    phone: normalized.e164,
    channel: resolvedChannel,
    createdAt: Date.now(),
  };

  await cache.set(otpKey, otpPayload, OTP_CONFIG.ttlSeconds);
  await cache.set(cooldownKey, { sentAt: Date.now() }, OTP_CONFIG.resendCooldownSeconds);

  const message = `Your GrabGo verification code is ${otp}. It expires in ${Math.ceil(
    OTP_CONFIG.ttlSeconds / 60
  )} minutes.`;

  const recipient = process.env.ARKESEL_USE_E164 === 'true' ? normalized.e164 : normalized.digits;
  const sendResult = await sendViaGateway({
    channel: resolvedChannel,
    to: recipient,
    message,
  });

  if (!sendResult.success) {
    await cache.del(otpKey);
    await cache.del(cooldownKey);
    return {
      success: false,
      message: 'Failed to send OTP. Please try again.',
      error: sendResult.error,
    };
  }

  await incrementCounter(sendCountKey, OTP_CONFIG.sendWindowSeconds);

  return {
    success: true,
    message: 'OTP sent successfully.',
    channel: resolvedChannel,
    otp: process.env.NODE_ENV === 'development' ? otp : undefined,
  };
};

const issuePhoneVerificationToken = async (phoneE164) => {
  const token = crypto.randomBytes(24).toString('hex');
  const key = getKey('verified', token);
  await cache.set(
    key,
    {
      phone: phoneE164,
      createdAt: Date.now(),
    },
    OTP_CONFIG.verifiedTokenTtlSeconds
  );
  return token;
};

const consumePhoneVerificationToken = async (token) => {
  if (!token) return null;
  const key = getKey('verified', token);
  const payload = await cache.get(key);
  if (!payload || !payload.phone) {
    return null;
  }
  await cache.del(key);
  return payload.phone;
};

const verifyPhoneOtp = async ({ phoneNumber, userId, otp }) => {
  const normalized = normalizeGhanaPhone(phoneNumber);
  if (!normalized) {
    return { success: false, message: 'Invalid Ghana phone number.' };
  }

  const otpKey = getKey('code', normalized.digits);
  const otpPayload = await cache.get(otpKey);
  if (!otpPayload) {
    return { success: false, message: 'OTP has expired or is invalid.' };
  }

  if (otpPayload.userId) {
    if (!userId) {
      return { success: false, message: 'OTP does not match this user.' };
    }
    if (otpPayload.userId !== userId) {
      return { success: false, message: 'OTP does not match this user.' };
    }
  }

  const attemptKey = getKey('verify', normalized.digits);
  const attempts = await getCounter(attemptKey);
  if (attempts >= OTP_CONFIG.maxVerifyAttempts) {
    await cache.set(getKey('lock', normalized.digits), true, OTP_CONFIG.lockoutSeconds);
    await cache.del(otpKey);
    return { success: false, message: 'Too many failed attempts. Please request a new OTP.' };
  }

  const hashed = hashOtp(String(otp), normalized.e164);
  if (hashed !== otpPayload.hash) {
    const newAttempts = await incrementCounter(attemptKey, OTP_CONFIG.ttlSeconds);
    if (newAttempts >= OTP_CONFIG.maxVerifyAttempts) {
      await cache.set(getKey('lock', normalized.digits), true, OTP_CONFIG.lockoutSeconds);
      await cache.del(otpKey);
      return { success: false, message: 'Too many failed attempts. Please request a new OTP.' };
    }
    return { success: false, message: 'Invalid OTP.' };
  }

  await cache.del(otpKey);
  await cache.del(attemptKey);

  let verificationToken;
  if (!otpPayload.userId) {
    verificationToken = await issuePhoneVerificationToken(normalized.e164);
  }

  return { success: true, phoneE164: normalized.e164, verificationToken };
};

module.exports = {
  normalizeGhanaPhone,
  requestPhoneOtp,
  verifyPhoneOtp,
  consumePhoneVerificationToken,
};
