const ACTION_TYPES = Object.freeze({
  AUTH_SIGNUP: 'auth_signup',
  AUTH_LOGIN: 'auth_login',
  ORDER_CREATE: 'order_create',
  PROMO_APPLY: 'promo_apply',
  REFERRAL_APPLY: 'referral_apply',
  PAYMENT_CLIENT_CONFIRM: 'payment_client_confirm',
  PAYMENT_WEBHOOK_EVENT: 'payment_webhook_event',
  RIDER_STATUS_UPDATE: 'rider_status_update',
  RIDER_ACCEPT_ORDER: 'rider_accept_order',
  ORDER_FULFILLMENT_TRANSITION: 'order_fulfillment_transition',
});

const DECISIONS = Object.freeze({
  ALLOW: 'allow',
  STEP_UP: 'step_up',
  BLOCK: 'block',
  ALLOW_DEGRADED: 'allow_degraded',
});

const CHALLENGE_TYPES = Object.freeze({
  OTP: 'otp',
  PAYMENT_REAUTH: 'payment_reauth',
  SUPPORT_ASSIST: 'support_assist',
});

const REASON_CODES = Object.freeze({
  CONTEXT_REQUIRED_MISSING: 'SYSTEM_CONTEXT_REQUIRED_MISSING',
  CONTEXT_TIMEOUT_DEGRADED: 'SYSTEM_CONTEXT_TIMEOUT_DEGRADED',
  PAYMENT_METADATA_MISMATCH: 'PAYMENT_METADATA_MISMATCH',
  PAYMENT_WEBHOOK_SIGNATURE_INVALID: 'PAYMENT_WEBHOOK_SIGNATURE_INVALID',
  PAYMENT_STATE_TRANSITION_INVALID: 'PAYMENT_STATE_TRANSITION_INVALID',
  ACCOUNT_TAKEOVER_CONFIRMED: 'ACCOUNT_TAKEOVER_CONFIRMED',
  ALLOWLIST_MATCH: 'SYSTEM_ALLOWLIST_MATCH',
  DENYLIST_MATCH_CONFIRMED: 'DENYLIST_MATCH_CONFIRMED',
  COLD_START_HIGH_VALUE_NEW_PAYMENT: 'ACCOUNT_COLD_START_HIGH_VALUE_NEW_PAYMENT',
  RIDER_COLD_START_LOCATION_ANOMALY: 'RIDER_COLD_START_LOCATION_ANOMALY',
  PROMO_VELOCITY_IP: 'PROMO_VELOCITY_IP',
  REFERRAL_VELOCITY_IP: 'REFERRAL_VELOCITY_IP',
  SIGNUP_VELOCITY_DEVICE: 'ACCOUNT_SIGNUP_VELOCITY_DEVICE',
  PAYMENT_ATTEMPT_VELOCITY_USER: 'PAYMENT_ATTEMPT_VELOCITY_USER',
  CHALLENGE_CAP_REACHED: 'SYSTEM_CHALLENGE_CAP_REACHED',
  HIGH_RISK_SCORE: 'SYSTEM_HIGH_RISK_SCORE',
  MEDIUM_RISK_SCORE: 'SYSTEM_MEDIUM_RISK_SCORE',
});

const CONTEXT_RULES = Object.freeze({
  [ACTION_TYPES.AUTH_SIGNUP]: {
    requiredFields: ['requestId', 'occurredAt', 'ipHash'],
    missingRequired: 'fail_open_flag',
    timeoutBehavior: 'fail_open_monitor',
  },
  [ACTION_TYPES.AUTH_LOGIN]: {
    requiredFields: ['requestId', 'occurredAt', 'ipHash', 'principal'],
    missingRequired: 'fail_open_stepup_on_velocity',
    timeoutBehavior: 'fail_open_monitor',
  },
  [ACTION_TYPES.ORDER_CREATE]: {
    requiredFields: ['orderId', 'actorId', 'amount', 'paymentMethod', 'ipHash'],
    missingRequired: 'fail_closed',
    timeoutBehavior: 'fail_closed',
  },
  [ACTION_TYPES.PROMO_APPLY]: {
    requiredFields: ['orderId', 'actorId', 'promoCode', 'ipHash'],
    missingRequired: 'fail_closed',
    timeoutBehavior: 'fail_closed',
  },
  [ACTION_TYPES.REFERRAL_APPLY]: {
    requiredFields: ['actorId', 'referralCode', 'ipHash'],
    missingRequired: 'fail_closed',
    timeoutBehavior: 'fail_closed',
  },
  [ACTION_TYPES.PAYMENT_CLIENT_CONFIRM]: {
    requiredFields: ['orderId', 'paymentRef', 'amount', 'currency'],
    missingRequired: 'fail_closed',
    timeoutBehavior: 'fail_closed',
  },
  [ACTION_TYPES.PAYMENT_WEBHOOK_EVENT]: {
    requiredFields: ['providerEventId', 'paymentRef', 'signature', 'amount'],
    missingRequired: 'fail_closed',
    timeoutBehavior: 'fail_closed',
  },
  [ACTION_TYPES.RIDER_STATUS_UPDATE]: {
    requiredFields: ['actorId', 'status', 'occurredAt'],
    missingRequired: 'fail_open_queue_anomaly',
    timeoutBehavior: 'fail_open_queue_anomaly',
  },
  [ACTION_TYPES.RIDER_ACCEPT_ORDER]: {
    requiredFields: ['actorId', 'orderId', 'occurredAt'],
    missingRequired: 'fail_closed',
    timeoutBehavior: 'conditional_fail_closed',
  },
  [ACTION_TYPES.ORDER_FULFILLMENT_TRANSITION]: {
    requiredFields: ['orderId', 'paymentState', 'actorId'],
    missingRequired: 'fail_closed',
    timeoutBehavior: 'fail_closed',
  },
});

const HARD_BLOCK_REASON_CODES = new Set([
  REASON_CODES.PAYMENT_METADATA_MISMATCH,
  REASON_CODES.PAYMENT_WEBHOOK_SIGNATURE_INVALID,
  REASON_CODES.ACCOUNT_TAKEOVER_CONFIRMED,
  REASON_CODES.DENYLIST_MATCH_CONFIRMED,
]);

module.exports = {
  ACTION_TYPES,
  CHALLENGE_TYPES,
  DECISIONS,
  REASON_CODES,
  CONTEXT_RULES,
  HARD_BLOCK_REASON_CODES,
};
