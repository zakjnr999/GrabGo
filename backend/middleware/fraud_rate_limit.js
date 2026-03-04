const cache = require('../utils/cache');
const { hashIdentifier } = require('../services/fraud/fraud_context');

const normalizeKeyValue = (value, fallback = 'unknown') => {
  if (value === null || value === undefined) return fallback;
  const normalized = String(value).trim();
  return normalized || fallback;
};

const toHashedKey = (value, namespace) =>
  hashIdentifier(normalizeKeyValue(value), namespace);

const getClientIp = (req) => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    return forwarded.split(',')[0].trim();
  }
  return req.headers['x-real-ip'] || req.ip || req.connection?.remoteAddress || req.socket?.remoteAddress || 'unknown';
};

const checkRule = async ({ key, limit, windowSeconds }) => {
  const count = await cache.incr(key, windowSeconds);
  const remaining = Math.max(0, limit - count);
  const retryAfter = await cache.ttl(key);
  return {
    exceeded: count > limit,
    count,
    remaining,
    retryAfter: retryAfter >= 0 ? retryAfter : windowSeconds,
  };
};

const sendRateLimit = (res, { reasonCode, message, retryAfter, limit, count, key }) => {
  return res.status(429).json({
    success: false,
    message: message || 'Too many requests',
    riskCode: reasonCode,
    reasonCodes: [reasonCode],
    data: {
      limit,
      count,
      retryAfter,
      key,
    },
  });
};

const ruleKey = (prefix, value) => `grabgo:fraud:throttle:${prefix}:${value || 'unknown'}`;

const createCompositeRateLimit = (rulesFactory) => {
  return async (req, res, next) => {
    try {
      const candidateRules = rulesFactory(req);
      const rules = Array.isArray(candidateRules) ? candidateRules : [];
      for (const rule of rules) {
        if (!rule || !rule.key || !Number.isFinite(rule.limit) || !Number.isFinite(rule.windowSeconds)) {
          continue;
        }

        const result = await checkRule(rule);
        if (result.exceeded) {
          return sendRateLimit(res, {
            reasonCode: rule.reasonCode,
            message: rule.message,
            retryAfter: result.retryAfter,
            limit: rule.limit,
            count: result.count,
            key: rule.key,
          });
        }
      }

      next();
    } catch (error) {
      console.error('[FraudRateLimit] Error:', error.message);
      next();
    }
  };
};

const signupRateLimit = createCompositeRateLimit((req) => {
  const ipHash = hashIdentifier(getClientIp(req), 'ip');
  const deviceId = req.headers['x-device-id'] || req.headers['x-app-instance-id'] || req.body?.deviceId;
  const rules = [
    {
      key: ruleKey('signup:ip', ipHash),
      limit: 20,
      windowSeconds: 3600,
      reasonCode: 'ACCOUNT_SIGNUP_VELOCITY_IP',
      message: 'Too many signup attempts from this network',
    },
  ];

  if (deviceId) {
    rules.push({
      key: ruleKey('signup:device', hashIdentifier(deviceId, 'device')),
      limit: 5,
      windowSeconds: 3600,
      reasonCode: 'ACCOUNT_SIGNUP_VELOCITY_DEVICE',
      message: 'Too many signup attempts from this device',
    });
  }

  return rules;
});

const promoApplyRateLimit = createCompositeRateLimit((req) => {
  const ipHash = hashIdentifier(getClientIp(req), 'ip');
  const userId = req.user?.id || 'guest';
  return [
    {
      key: ruleKey('promo:ip:min', ipHash),
      limit: 20,
      windowSeconds: 60,
      reasonCode: 'PROMO_VELOCITY_IP',
      message: 'Promo attempts are temporarily rate limited for this network',
    },
    {
      key: ruleKey('promo:user:hour', userId),
      limit: 10,
      windowSeconds: 3600,
      reasonCode: 'PROMO_VELOCITY_USER',
      message: 'Promo attempts are temporarily rate limited for this account',
    },
  ];
});

const referralApplyRateLimit = createCompositeRateLimit((req) => {
  const ipHash = hashIdentifier(getClientIp(req), 'ip');
  const userId = req.user?.id || 'guest';
  return [
    {
      key: ruleKey('referral:ip:hour', ipHash),
      limit: 10,
      windowSeconds: 3600,
      reasonCode: 'REFERRAL_VELOCITY_IP',
      message: 'Referral attempts are temporarily rate limited for this network',
    },
    {
      key: ruleKey('referral:user:day', userId),
      limit: 5,
      windowSeconds: 86400,
      reasonCode: 'REFERRAL_VELOCITY_USER',
      message: 'Referral attempts are temporarily rate limited for this account',
    },
  ];
});

const paymentAttemptRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const paymentToken =
    req.body?.paymentToken ||
    req.body?.reference ||
    req.body?.paymentReference ||
    req.body?.providerEventId ||
    null;

  const rules = [
    {
      key: ruleKey('payment:user:10m', userId),
      limit: 5,
      windowSeconds: 600,
      reasonCode: 'PAYMENT_ATTEMPT_VELOCITY_USER',
      message: 'Too many payment attempts from this account',
    },
  ];

  if (paymentToken) {
    rules.push({
      key: ruleKey('payment:token:10m', hashIdentifier(paymentToken, 'payment_token')),
      limit: 8,
      windowSeconds: 600,
      reasonCode: 'PAYMENT_ATTEMPT_VELOCITY_TOKEN',
      message: 'Too many payment attempts for this payment method',
    });
  }

  return rules;
});

const apiGlobalRateLimit = createCompositeRateLimit((req) => {
  const fullPath = `${req.baseUrl || ''}${req.path || ''}`;
  if (fullPath.startsWith('/api/payments/webhooks/')) {
    return [];
  }

  const ipHash = toHashedKey(getClientIp(req), 'ip');
  return [
    {
      key: ruleKey('api:ip:min', ipHash),
      limit: 400,
      windowSeconds: 60,
      reasonCode: 'API_VELOCITY_IP',
      message: 'Too many requests from this network',
    },
  ];
});

const loginRateLimit = createCompositeRateLimit((req) => {
  const ipHash = toHashedKey(getClientIp(req), 'ip');
  const principalHash = toHashedKey(
    req.body?.email || req.body?.googleId || req.body?.phone || 'anonymous_login',
    'principal'
  );

  return [
    {
      key: ruleKey('login:ip:10m', ipHash),
      limit: 80,
      windowSeconds: 600,
      reasonCode: 'AUTH_LOGIN_VELOCITY_IP',
      message: 'Too many login attempts from this network',
    },
    {
      key: ruleKey('login:principal:10m', principalHash),
      limit: 20,
      windowSeconds: 600,
      reasonCode: 'AUTH_LOGIN_VELOCITY_ACCOUNT',
      message: 'Too many login attempts for this account',
    },
  ];
});

const phoneOtpSendRateLimit = createCompositeRateLimit((req) => {
  const ipHash = toHashedKey(getClientIp(req), 'ip');
  const phoneHash = toHashedKey(req.body?.phoneNumber || req.body?.phone || req.user?.phone || 'unknown_phone', 'phone');
  const userId = req.user?.id || req.body?.userId || null;

  const rules = [
    {
      key: ruleKey('otp:send:ip:10m', ipHash),
      limit: 50,
      windowSeconds: 600,
      reasonCode: 'OTP_SEND_VELOCITY_IP',
      message: 'Too many OTP send attempts from this network',
    },
    {
      key: ruleKey('otp:send:phone:10m', phoneHash),
      limit: 8,
      windowSeconds: 600,
      reasonCode: 'OTP_SEND_VELOCITY_PHONE',
      message: 'Too many OTP send attempts for this phone number',
    },
  ];

  if (userId) {
    rules.push({
      key: ruleKey('otp:send:user:10m', userId),
      limit: 10,
      windowSeconds: 600,
      reasonCode: 'OTP_SEND_VELOCITY_USER',
      message: 'Too many OTP send attempts for this account',
    });
  }

  return rules;
});

const phoneOtpVerifyRateLimit = createCompositeRateLimit((req) => {
  const ipHash = toHashedKey(getClientIp(req), 'ip');
  const phoneHash = toHashedKey(req.body?.phoneNumber || req.body?.phone || req.user?.phone || 'unknown_phone', 'phone');
  const userId = req.user?.id || req.body?.userId || null;

  const rules = [
    {
      key: ruleKey('otp:verify:ip:10m', ipHash),
      limit: 100,
      windowSeconds: 600,
      reasonCode: 'OTP_VERIFY_VELOCITY_IP',
      message: 'Too many OTP verification attempts from this network',
    },
    {
      key: ruleKey('otp:verify:phone:10m', phoneHash),
      limit: 20,
      windowSeconds: 600,
      reasonCode: 'OTP_VERIFY_VELOCITY_PHONE',
      message: 'Too many OTP verification attempts for this phone number',
    },
  ];

  if (userId) {
    rules.push({
      key: ruleKey('otp:verify:user:10m', userId),
      limit: 25,
      windowSeconds: 600,
      reasonCode: 'OTP_VERIFY_VELOCITY_USER',
      message: 'Too many OTP verification attempts for this account',
    });
  }

  return rules;
});

const emailVerificationRateLimit = createCompositeRateLimit((req) => {
  const ipHash = toHashedKey(getClientIp(req), 'ip');
  const emailHash = toHashedKey(req.body?.email || req.user?.email || 'unknown_email', 'email');

  return [
    {
      key: ruleKey('email:verify:ip:10m', ipHash),
      limit: 40,
      windowSeconds: 600,
      reasonCode: 'EMAIL_VERIFICATION_VELOCITY_IP',
      message: 'Too many email verification attempts from this network',
    },
    {
      key: ruleKey('email:verify:email:10m', emailHash),
      limit: 10,
      windowSeconds: 600,
      reasonCode: 'EMAIL_VERIFICATION_VELOCITY_EMAIL',
      message: 'Too many email verification attempts for this email',
    },
  ];
});

const parcelQuoteRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const ipHash = toHashedKey(getClientIp(req), 'ip');

  return [
    {
      key: ruleKey('parcel:quote:user:10m', userId),
      limit: 30,
      windowSeconds: 600,
      reasonCode: 'PARCEL_QUOTE_VELOCITY_USER',
      message: 'Too many parcel quote requests for this account',
    },
    {
      key: ruleKey('parcel:quote:ip:10m', ipHash),
      limit: 120,
      windowSeconds: 600,
      reasonCode: 'PARCEL_QUOTE_VELOCITY_IP',
      message: 'Too many parcel quote requests from this network',
    },
  ];
});

const parcelOrderCreateRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const ipHash = toHashedKey(getClientIp(req), 'ip');

  return [
    {
      key: ruleKey('parcel:create:user:10m', userId),
      limit: 12,
      windowSeconds: 600,
      reasonCode: 'PARCEL_CREATE_VELOCITY_USER',
      message: 'Too many parcel creation attempts for this account',
    },
    {
      key: ruleKey('parcel:create:ip:10m', ipHash),
      limit: 40,
      windowSeconds: 600,
      reasonCode: 'PARCEL_CREATE_VELOCITY_IP',
      message: 'Too many parcel creation attempts from this network',
    },
  ];
});

const parcelLifecycleRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  return [
    {
      key: ruleKey('parcel:lifecycle:user:10m', userId),
      limit: 40,
      windowSeconds: 600,
      reasonCode: 'PARCEL_LIFECYCLE_VELOCITY_USER',
      message: 'Too many parcel updates for this account',
    },
  ];
});

const parcelDeliveryCodeRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const parcelId = req.params?.parcelId || 'unknown_parcel';

  return [
    {
      key: ruleKey('parcel:delivery-code:user:10m', userId),
      limit: 6,
      windowSeconds: 600,
      reasonCode: 'PARCEL_DELIVERY_CODE_VELOCITY_USER',
      message: 'Too many delivery code resend attempts for this account',
    },
    {
      key: ruleKey('parcel:delivery-code:parcel:10m', parcelId),
      limit: 4,
      windowSeconds: 600,
      reasonCode: 'PARCEL_DELIVERY_CODE_VELOCITY_PARCEL',
      message: 'Too many delivery code resend attempts for this parcel',
    },
  ];
});

const trackingInitializeRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const orderId = req.body?.orderId || req.params?.orderId || 'unknown_order';
  return [
    {
      key: ruleKey('tracking:init:user:10m', userId),
      limit: 60,
      windowSeconds: 600,
      reasonCode: 'TRACKING_INIT_VELOCITY_USER',
      message: 'Too many tracking initialization requests for this account',
    },
    {
      key: ruleKey('tracking:init:order:10m', orderId),
      limit: 10,
      windowSeconds: 600,
      reasonCode: 'TRACKING_INIT_VELOCITY_ORDER',
      message: 'Too many tracking initialization requests for this order',
    },
  ];
});

const trackingLocationRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const orderId = req.body?.orderId || req.params?.orderId || 'unknown_order';
  return [
    {
      key: ruleKey('tracking:location:user:10m', userId),
      limit: 1200,
      windowSeconds: 600,
      reasonCode: 'TRACKING_LOCATION_VELOCITY_USER',
      message: 'Too many tracking location updates for this account',
    },
    {
      key: ruleKey('tracking:location:order:10m', orderId),
      limit: 900,
      windowSeconds: 600,
      reasonCode: 'TRACKING_LOCATION_VELOCITY_ORDER',
      message: 'Too many tracking location updates for this order',
    },
  ];
});

const trackingStatusRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const orderId = req.body?.orderId || req.params?.orderId || 'unknown_order';
  return [
    {
      key: ruleKey('tracking:status:user:10m', userId),
      limit: 180,
      windowSeconds: 600,
      reasonCode: 'TRACKING_STATUS_VELOCITY_USER',
      message: 'Too many tracking status updates for this account',
    },
    {
      key: ruleKey('tracking:status:order:10m', orderId),
      limit: 60,
      windowSeconds: 600,
      reasonCode: 'TRACKING_STATUS_VELOCITY_ORDER',
      message: 'Too many tracking status updates for this order',
    },
  ];
});

const chatMessageRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const chatId = req.params?.chatId || 'unknown_chat';
  return [
    {
      key: ruleKey('chat:message:user:1m', userId),
      limit: 60,
      windowSeconds: 60,
      reasonCode: 'CHAT_MESSAGE_VELOCITY_USER',
      message: 'Too many chat messages from this account',
    },
    {
      key: ruleKey('chat:message:chat:1m', chatId),
      limit: 120,
      windowSeconds: 60,
      reasonCode: 'CHAT_MESSAGE_VELOCITY_CHAT',
      message: 'Too many messages in this chat',
    },
  ];
});

const chatMediaRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const chatId = req.params?.chatId || 'unknown_chat';
  return [
    {
      key: ruleKey('chat:media:user:10m', userId),
      limit: 40,
      windowSeconds: 600,
      reasonCode: 'CHAT_MEDIA_VELOCITY_USER',
      message: 'Too many chat media uploads from this account',
    },
    {
      key: ruleKey('chat:media:chat:10m', chatId),
      limit: 100,
      windowSeconds: 600,
      reasonCode: 'CHAT_MEDIA_VELOCITY_CHAT',
      message: 'Too many media uploads in this chat',
    },
  ];
});

const callTurnCredentialsRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const ipHash = toHashedKey(getClientIp(req), 'ip');
  return [
    {
      key: ruleKey('calls:turn:user:1m', userId),
      limit: 30,
      windowSeconds: 60,
      reasonCode: 'CALL_TURN_VELOCITY_USER',
      message: 'Too many TURN credential requests for this account',
    },
    {
      key: ruleKey('calls:turn:ip:1m', ipHash),
      limit: 120,
      windowSeconds: 60,
      reasonCode: 'CALL_TURN_VELOCITY_IP',
      message: 'Too many TURN credential requests from this network',
    },
  ];
});

const fraudChallengeSendRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const ipHash = toHashedKey(getClientIp(req), 'ip');
  return [
    {
      key: ruleKey('fraud:challenge:send:user:10m', userId),
      limit: 12,
      windowSeconds: 600,
      reasonCode: 'FRAUD_CHALLENGE_SEND_VELOCITY_USER',
      message: 'Too many challenge requests for this account',
    },
    {
      key: ruleKey('fraud:challenge:send:ip:10m', ipHash),
      limit: 40,
      windowSeconds: 600,
      reasonCode: 'FRAUD_CHALLENGE_SEND_VELOCITY_IP',
      message: 'Too many challenge requests from this network',
    },
  ];
});

const fraudChallengeVerifyRateLimit = createCompositeRateLimit((req) => {
  const userId = req.user?.id || 'guest';
  const ipHash = toHashedKey(getClientIp(req), 'ip');
  return [
    {
      key: ruleKey('fraud:challenge:verify:user:10m', userId),
      limit: 30,
      windowSeconds: 600,
      reasonCode: 'FRAUD_CHALLENGE_VERIFY_VELOCITY_USER',
      message: 'Too many challenge verification attempts for this account',
    },
    {
      key: ruleKey('fraud:challenge:verify:ip:10m', ipHash),
      limit: 100,
      windowSeconds: 600,
      reasonCode: 'FRAUD_CHALLENGE_VERIFY_VELOCITY_IP',
      message: 'Too many challenge verification attempts from this network',
    },
  ];
});

module.exports = {
  apiGlobalRateLimit,
  signupRateLimit,
  loginRateLimit,
  phoneOtpSendRateLimit,
  phoneOtpVerifyRateLimit,
  emailVerificationRateLimit,
  promoApplyRateLimit,
  referralApplyRateLimit,
  paymentAttemptRateLimit,
  parcelQuoteRateLimit,
  parcelOrderCreateRateLimit,
  parcelLifecycleRateLimit,
  parcelDeliveryCodeRateLimit,
  trackingInitializeRateLimit,
  trackingLocationRateLimit,
  trackingStatusRateLimit,
  chatMessageRateLimit,
  chatMediaRateLimit,
  callTurnCredentialsRateLimit,
  fraudChallengeSendRateLimit,
  fraudChallengeVerifyRateLimit,
};
