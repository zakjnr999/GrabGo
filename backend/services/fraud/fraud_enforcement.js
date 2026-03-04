const featureFlags = require('../../config/feature_flags');
const { DECISIONS } = require('./constants');

const shouldEnforce = () => {
  if (!featureFlags.isFraudEnabled) return false;
  if (featureFlags.isFraudShadowMode) return false;
  return true;
};

const applyFraudDecision = ({ req, res, decision, actionType }) => {
  const enforce = shouldEnforce();

  if (!enforce) {
    return { blocked: false, challenged: false, shadowOnly: true };
  }

  if (decision.decision === DECISIONS.BLOCK) {
    res.status(403).json({
      success: false,
      message: 'Action blocked by risk policy',
      riskCode: 'RISK_BLOCKED',
      actionType,
      decision: decision.decision,
      score: decision.score,
      reasonCodes: decision.reasonCodes,
      policyVersion: decision.policy?.version || 1,
      policyChecksum: decision.policy?.checksum || null,
    });
    return { blocked: true, challenged: false, shadowOnly: false };
  }

  if (decision.decision === DECISIONS.STEP_UP) {
    res.status(403).json({
      success: false,
      message: 'Additional verification required',
      riskCode: 'RISK_STEP_UP_REQUIRED',
      actionType,
      challengeRequired: true,
      challengeType: decision.challengeType,
      decision: decision.decision,
      score: decision.score,
      reasonCodes: decision.reasonCodes,
      policyVersion: decision.policy?.version || 1,
      policyChecksum: decision.policy?.checksum || null,
    });
    return { blocked: false, challenged: true, shadowOnly: false };
  }

  req.fraudDecision = decision;
  return { blocked: false, challenged: false, shadowOnly: false };
};

module.exports = {
  applyFraudDecision,
  shouldEnforce,
};
