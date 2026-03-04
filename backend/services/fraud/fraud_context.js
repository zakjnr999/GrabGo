const crypto = require('crypto');
const { CONTEXT_RULES } = require('./constants');

const FRAUD_CONTEXT_VERSION = 1;

const isPlainObject = (value) => Boolean(value) && typeof value === 'object' && !Array.isArray(value);

const normalizeValue = (value) => {
  if (value === undefined) return null;
  if (value === null) return null;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) return null;
    return Number(value);
  }
  if (typeof value === 'string') return value;
  if (typeof value === 'boolean') return value;
  if (Array.isArray(value)) return value.map((entry) => normalizeValue(entry));
  if (isPlainObject(value)) {
    const keys = Object.keys(value).sort();
    const out = {};
    for (const key of keys) {
      out[key] = normalizeValue(value[key]);
    }
    return out;
  }
  return String(value);
};

const canonicalJSONStringify = (value) => JSON.stringify(normalizeValue(value));

const computeContextHash = ({ actionType, contextVersion, context }) => {
  const canonical = canonicalJSONStringify(context);
  const input = `${String(actionType || '')}|${String(contextVersion || FRAUD_CONTEXT_VERSION)}|${canonical}`;
  return crypto.createHash('sha256').update(input).digest('hex');
};

const getClientIp = (req) => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    return forwarded.split(',')[0].trim();
  }
  return (
    req.headers['x-real-ip'] ||
    req.ip ||
    req.connection?.remoteAddress ||
    req.socket?.remoteAddress ||
    null
  );
};

const hashIdentifier = (value, purpose = 'generic') => {
  if (!value) return null;
  const secret = process.env.FRAUD_HASH_SECRET || process.env.JWT_SECRET || 'grabgo-fraud-hash-secret';
  return crypto.createHmac('sha256', `${secret}:${purpose}`).update(String(value)).digest('hex');
};

const buildFraudContext = ({ actionType, actorType, actorId, requestId, context = {} }) => {
  const base = {
    contextVersion: FRAUD_CONTEXT_VERSION,
    actionType,
    requestId: requestId || crypto.randomUUID(),
    occurredAt: context.occurredAt || new Date().toISOString(),
    actorType: actorType || null,
    actorId: actorId || null,
    sessionId: context.sessionId || null,
    appInstanceId: context.appInstanceId || null,
    ipHash: context.ipHash || null,
    userAgentHash: context.userAgentHash || null,
    geo: context.geo || null,
    paymentRef: context.paymentRef || null,
    orderId: context.orderId || null,
    metadata: context.metadata || {},
    principal: context.principal || null,
    amount: context.amount ?? null,
    currency: context.currency || null,
    paymentMethod: context.paymentMethod || null,
    referralCode: context.referralCode || null,
    promoCode: context.promoCode || null,
    status: context.status || null,
    paymentState: context.paymentState || null,
    providerEventId: context.providerEventId || null,
    signature: context.signature || null,
  };

  const contextHash = computeContextHash({
    actionType,
    contextVersion: FRAUD_CONTEXT_VERSION,
    context: base,
  });

  return {
    ...base,
    contextHash,
  };
};

const buildFraudContextFromRequest = ({ req, actionType, actorType, actorId, extras = {} }) => {
  const ip = getClientIp(req);
  const userAgent = req.headers['user-agent'] || null;

  return buildFraudContext({
    actionType,
    actorType,
    actorId,
    requestId: req.headers['x-request-id'] || req.headers['x-correlation-id'] || crypto.randomUUID(),
    context: {
      ipHash: hashIdentifier(ip, 'ip'),
      userAgentHash: hashIdentifier(userAgent, 'ua'),
      appInstanceId: req.headers['x-device-id'] || req.headers['x-app-instance-id'] || null,
      ...extras,
    },
  });
};

const validateContext = ({ actionType, context }) => {
  const rule = CONTEXT_RULES[actionType] || { requiredFields: [], missingRequired: 'fail_open_flag', timeoutBehavior: 'fail_open_monitor' };
  const missing = [];

  for (const field of rule.requiredFields) {
    if (context[field] === null || context[field] === undefined || context[field] === '') {
      missing.push(field);
    }
  }

  return {
    valid: missing.length === 0,
    missing,
    rule,
  };
};

module.exports = {
  FRAUD_CONTEXT_VERSION,
  canonicalJSONStringify,
  computeContextHash,
  buildFraudContext,
  buildFraudContextFromRequest,
  validateContext,
  getClientIp,
  hashIdentifier,
};
