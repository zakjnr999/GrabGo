const cache = require('../utils/cache');
const { hashIdentifier } = require('../services/fraud/fraud_context');

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

module.exports = {
  signupRateLimit,
  promoApplyRateLimit,
  referralApplyRateLimit,
  paymentAttemptRateLimit,
};
