const crypto = require('crypto');
const prisma = require('../../config/prisma');

const DEFAULT_POLICY_VERSION = Number(process.env.FRAUD_POLICY_VERSION || 1);
const hasDelegate = (name) => Boolean(prisma?.[name] && typeof prisma[name] === 'object');

const defaultPolicyObject = () => ({
  version: DEFAULT_POLICY_VERSION,
  thresholds: {
    allowMax: Number(process.env.FRAUD_ALLOW_MAX || 34),
    stepUpMax: Number(process.env.FRAUD_STEP_UP_MAX || 69),
    blockMin: Number(process.env.FRAUD_BLOCK_MIN || 70),
    highValueOrderAmount: Number(process.env.FRAUD_HIGH_VALUE_ORDER_AMOUNT || 150),
  },
  rule_weights: {
    velocity_ip_promo: 25,
    velocity_ip_referral: 20,
    velocity_device_signup: 20,
    velocity_payment_attempt: 25,
    cold_start_order: 30,
    cold_start_rider: 30,
    graph_cluster_hit: 20,
  },
  challenge_caps: {
    perActionPer24h: Number(process.env.FRAUD_CHALLENGE_CAP_PER_ACTION_24H || 1),
    totalPer24h: Number(process.env.FRAUD_CHALLENGE_CAP_TOTAL_24H || 3),
  },
  rule_toggles: {
    cold_start_customer: true,
    cold_start_rider: true,
    velocity_checks: true,
    graph_checks: true,
    hard_block_overrides: true,
    shadow_mode: process.env.FRAUD_SHADOW_MODE !== 'false',
  },
});

const canonical = (value) => JSON.stringify(value);

const checksum = (policy) => {
  const payload = canonical({
    version: policy.version,
    thresholds: policy.thresholds,
    rule_weights: policy.rule_weights,
    challenge_caps: policy.challenge_caps,
    rule_toggles: policy.rule_toggles,
  });
  return crypto.createHash('sha256').update(payload).digest('hex');
};

const normalizePolicyRecord = (record) => {
  if (!record) return null;
  return {
    version: record.version,
    thresholds: record.thresholds,
    rule_weights: record.ruleWeights,
    challenge_caps: record.challengeCaps,
    rule_toggles: record.ruleToggles,
    checksum: record.checksum,
    effective_at: record.effectiveAt,
    is_active: record.isActive,
  };
};

const getActivePolicy = async () => {
  const fallback = defaultPolicyObject();
  if (!hasDelegate("fraudPolicy")) {
    fallback.checksum = checksum(fallback);
    return fallback;
  }
  fallback.checksum = checksum(fallback);

  try {
    const active = await prisma.fraudPolicy.findFirst({
      where: { isActive: true },
      orderBy: [{ effectiveAt: 'desc' }, { version: 'desc' }],
    });

    if (!active) {
      return fallback;
    }

    const normalized = normalizePolicyRecord(active);
    return {
      ...normalized,
      checksum: normalized.checksum || checksum(normalized),
    };
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudPolicy')) {
      return fallback;
    }
    throw error;
  }
};

const ensureDefaultPolicy = async () => {
  if (!hasDelegate("fraudPolicy")) return;
  const policy = defaultPolicyObject();
  const policyChecksum = checksum(policy);

  try {
    const existing = await prisma.fraudPolicy.findUnique({ where: { version: policy.version } });
    if (existing) {
      if (!existing.isActive) {
        await prisma.fraudPolicy.update({
          where: { id: existing.id },
          data: {
            isActive: true,
            checksum: policyChecksum,
            thresholds: policy.thresholds,
            ruleWeights: policy.rule_weights,
            challengeCaps: policy.challenge_caps,
            ruleToggles: policy.rule_toggles,
            effectiveAt: new Date(),
          },
        });
      }
      return;
    }

    await prisma.fraudPolicy.create({
      data: {
        version: policy.version,
        checksum: policyChecksum,
        thresholds: policy.thresholds,
        ruleWeights: policy.rule_weights,
        challengeCaps: policy.challenge_caps,
        ruleToggles: policy.rule_toggles,
        effectiveAt: new Date(),
        isActive: true,
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudPolicy')) {
      console.warn('[Fraud] FraudPolicy table not ready yet; skipping default policy bootstrap.');
      return;
    }
    throw error;
  }
};

module.exports = {
  DEFAULT_POLICY_VERSION,
  defaultPolicyObject,
  checksum,
  getActivePolicy,
  ensureDefaultPolicy,
};
