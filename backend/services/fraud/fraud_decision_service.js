const prisma = require('../../config/prisma');
const cache = require('../../utils/cache');
const {
  ACTION_TYPES,
  DECISIONS,
  CHALLENGE_TYPES,
  REASON_CODES,
  HARD_BLOCK_REASON_CODES,
} = require('./constants');
const { validateContext } = require('./fraud_context');
const { getActivePolicy } = require('./fraud_policy_service');
const { setFeature, upsertFeatureDefinition } = require('./fraud_feature_store');
const { upsertEdge, computeSharedEntityDegree, saveMetric } = require('./fraud_graph_service');
const { enqueueOutboxEvent } = require('./fraud_event_service');
const { createCase } = require('./fraud_case_service');
const { checkChallengeCaps } = require('./fraud_challenge_service');

const hasDelegate = (name) => Boolean(prisma?.[name] && typeof prisma[name] === 'object');
const tableUnavailable = (error, delegateName) => {
  const message = String(error?.message || '');
  return (
    message.includes(delegateName) ||
    message.includes('Cannot read properties of undefined') ||
    message.includes('is not a function')
  );
};

const recordDecision = async ({
  actorType,
  actorId,
  actionType,
  score,
  decision,
  reasonCodes,
  reasonDetails,
  challengeType,
  policy,
  context,
  shadowMode,
}) => {
  if (!hasDelegate('fraudDecision')) return null;
  try {
    return await prisma.fraudDecision.create({
      data: {
        actorType,
        actorId,
        actionType,
        score,
        decision,
        reasonCodes,
        reasonDetails,
        challengeType: challengeType || null,
        policyVersion: policy.version,
        policyChecksum: policy.checksum,
        contextVersion: context.contextVersion,
        contextHash: context.contextHash,
        requestId: context.requestId || null,
        shadowMode: !!shadowMode,
        metadata: {
          ipHash: context.ipHash || null,
          appInstanceId: context.appInstanceId || null,
          occurredAt: context.occurredAt,
        },
      },
    });
  } catch (error) {
    if (tableUnavailable(error, 'prisma.fraudDecision')) {
      return null;
    }
    throw error;
  }
};

const upsertProfile = async ({ actorType, actorId, riskScore, riskLevel, featureSnapshot, graphSnapshot }) => {
  if (!hasDelegate('fraudSubjectProfile')) return null;
  try {
    return await prisma.fraudSubjectProfile.upsert({
      where: {
        actorType_actorId: {
          actorType,
          actorId,
        },
      },
      update: {
        riskScore,
        riskLevel,
        featureSnapshot,
        graphSnapshot,
      },
      create: {
        actorType,
        actorId,
        riskScore,
        riskLevel,
        featureSnapshot,
        graphSnapshot,
      },
    });
  } catch (error) {
    if (tableUnavailable(error, 'prisma.fraudSubjectProfile')) {
      return null;
    }
    throw error;
  }
};

const getAccountAge = async ({ actorId }) => {
  if (!actorId) return null;
  try {
    const user = await prisma.user.findUnique({
      where: { id: actorId },
      select: { createdAt: true },
    });
    if (!user?.createdAt) return null;
    const ageMs = Date.now() - new Date(user.createdAt).getTime();
    return {
      minutes: Math.floor(ageMs / 60000),
      days: ageMs / (24 * 60 * 60 * 1000),
    };
  } catch {
    return null;
  }
};

const checkSignalHit = async ({ actorType, actorId, signalType }) => {
  if (!hasDelegate('fraudSignal')) return false;
  try {
    const signal = await prisma.fraudSignal.findFirst({
      where: {
        actorType,
        actorId,
        signalType,
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } },
        ],
      },
      orderBy: { observedAt: 'desc' },
    });
    return Boolean(signal);
  } catch (error) {
    if (tableUnavailable(error, 'prisma.fraudSignal')) {
      return false;
    }
    throw error;
  }
};

const scoreToRiskLevel = (score) => {
  if (score >= 70) return 'high';
  if (score >= 35) return 'medium';
  return 'low';
};

const resolveDecision = ({ score, policy, reasonCodes }) => {
  for (const code of reasonCodes) {
    if (HARD_BLOCK_REASON_CODES.has(code)) {
      return DECISIONS.BLOCK;
    }
  }

  const thresholds = policy.thresholds || {};
  const allowMax = Number(thresholds.allowMax ?? 34);
  const stepUpMax = Number(thresholds.stepUpMax ?? 69);

  if (score > stepUpMax) return DECISIONS.BLOCK;
  if (score > allowMax) return DECISIONS.STEP_UP;
  return DECISIONS.ALLOW;
};

const velocityCounter = async ({ key, ttlSeconds }) => {
  const count = await cache.incr(key, ttlSeconds);
  return Number(count || 0);
};

const ensureFeatureDefinitions = async () => {
  const features = [
    ['orders_last_1h', 'Orders in rolling 1 hour', 3600],
    ['orders_last_24h', 'Orders in rolling 24 hours', 86400],
    ['failed_payments_last_10m', 'Failed payments in rolling 10 minutes', 600],
    ['unique_devices_last_7d', 'Unique devices in 7 days', 604800],
    ['promo_attempts_last_1h', 'Promo attempts in rolling 1 hour', 3600],
    ['refund_rate_30d', 'Refund rate in rolling 30 days', 2592000],
    ['driver_cancel_rate_7d', 'Rider cancellation rate in 7 days', 604800],
    ['rider_restaurant_affinity_14d', 'Share of rider orders from top vendor in 14 days', 1209600],
    ['rider_customer_repeat_pair_30d', 'Repeat deliveries between rider and same customer in 30 days', 2592000],
  ];

  for (const [featureName, description, windowSeconds] of features) {
    await upsertFeatureDefinition({ featureName, featureVersion: 1, description, windowSeconds, isActive: true });
  }
};

const applyGraphSignals = async ({ actorType, actorId, context, scoreState }) => {
  if (!actorType || !actorId) return;

  const edges = [];
  if (context.appInstanceId) {
    edges.push({ edgeType: 'actor_device', toEntityType: 'device', toEntityId: context.appInstanceId });
  }
  if (context.ipHash) {
    edges.push({ edgeType: 'actor_ip', toEntityType: 'ip_hash', toEntityId: context.ipHash });
  }
  if (context.metadata?.paymentToken) {
    edges.push({ edgeType: 'actor_payment', toEntityType: 'payment_method_token', toEntityId: context.metadata.paymentToken });
  }
  if (context.metadata?.addressHash) {
    edges.push({ edgeType: 'actor_address', toEntityType: 'address_hash', toEntityId: context.metadata.addressHash });
  }
  if (context.referralCode) {
    edges.push({ edgeType: 'actor_referral_code', toEntityType: 'referral_code', toEntityId: context.referralCode });
  }

  for (const edge of edges) {
    await upsertEdge({
      fromActorType: actorType,
      fromActorId: actorId,
      edgeType: edge.edgeType,
      toEntityType: edge.toEntityType,
      toEntityId: edge.toEntityId,
      weight: 1,
    });

    const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const degree = await computeSharedEntityDegree({
      edgeType: edge.edgeType,
      toEntityType: edge.toEntityType,
      toEntityId: edge.toEntityId,
      since,
    });

    await saveMetric({
      actorType,
      actorId,
      metricName: `shared_${edge.toEntityType}_degree_7d`,
      metricWindow: '7d',
      metricValue: degree,
    });

    if (degree >= 6) {
      scoreState.score += 20;
      scoreState.reasonCodes.add(REASON_CODES.HIGH_RISK_SCORE);
      scoreState.reasonDetails.sharedEntity = {
        edgeType: edge.edgeType,
        toEntityType: edge.toEntityType,
        degree,
      };
    }
  }
};

const applyVelocitySignals = async ({ actionType, actorType, actorId, context, scoreState }) => {
  if (actionType === ACTION_TYPES.PROMO_APPLY && context.ipHash) {
    const count = await velocityCounter({ key: `grabgo:fraud:velocity:promo_apply:ip:${context.ipHash}`, ttlSeconds: 60 });
    await setFeature({ actorType, actorId, featureName: 'promo_attempts_last_1h', value: { count }, expiresAt: new Date(Date.now() + 3600 * 1000) });
    if (count > 20) {
      scoreState.score += 25;
      scoreState.reasonCodes.add(REASON_CODES.PROMO_VELOCITY_IP);
      scoreState.reasonDetails.promoAttemptCount = count;
    }
  }

  if (actionType === ACTION_TYPES.REFERRAL_APPLY && context.ipHash) {
    const count = await velocityCounter({ key: `grabgo:fraud:velocity:referral_apply:ip:${context.ipHash}`, ttlSeconds: 3600 });
    if (count > 10) {
      scoreState.score += 20;
      scoreState.reasonCodes.add(REASON_CODES.REFERRAL_VELOCITY_IP);
      scoreState.reasonDetails.referralAttemptCount = count;
    }
  }

  if (actionType === ACTION_TYPES.AUTH_SIGNUP && context.appInstanceId) {
    const count = await velocityCounter({ key: `grabgo:fraud:velocity:signup:device:${context.appInstanceId}`, ttlSeconds: 3600 });
    if (count > 5) {
      scoreState.score += 20;
      scoreState.reasonCodes.add(REASON_CODES.SIGNUP_VELOCITY_DEVICE);
      scoreState.reasonDetails.signupDeviceCount = count;
    }
  }

  if (actionType === ACTION_TYPES.PAYMENT_CLIENT_CONFIRM && actorId) {
    const count = await velocityCounter({ key: `grabgo:fraud:velocity:payment_attempt:user:${actorId}`, ttlSeconds: 600 });
    if (count > 5) {
      scoreState.score += 25;
      scoreState.reasonCodes.add(REASON_CODES.PAYMENT_ATTEMPT_VELOCITY_USER);
      scoreState.reasonDetails.paymentAttemptCount = count;
    }
  }
};

const applyColdStartSignals = async ({ actionType, actorType, actorId, context, scoreState, policy }) => {
  const age = await getAccountAge({ actorId });
  const threshold = Number(policy.thresholds?.highValueOrderAmount || 150);

  if (actionType === ACTION_TYPES.ORDER_CREATE) {
    const accountAgeMinutes = Number(context.metadata?.accountAgeMinutes ?? age?.minutes ?? Number.NaN);
    const orderValue = Number(context.amount || context.metadata?.orderValue || 0);
    const newPaymentMethod = Boolean(context.metadata?.newPaymentMethod);

    if (Number.isFinite(accountAgeMinutes) && accountAgeMinutes < 10 && orderValue >= threshold && newPaymentMethod) {
      scoreState.score += 30;
      scoreState.reasonCodes.add(REASON_CODES.COLD_START_HIGH_VALUE_NEW_PAYMENT);
      scoreState.reasonDetails.coldStart = { accountAgeMinutes, orderValue, newPaymentMethod };
    }
  }

  if (actionType === ACTION_TYPES.RIDER_ACCEPT_ORDER || actionType === ACTION_TYPES.RIDER_STATUS_UPDATE) {
    const riderAgeDays = Number(context.metadata?.riderAgeDays ?? age?.days ?? Number.NaN);
    const highValueOrder = Boolean(context.metadata?.highValueOrder);
    const locationAnomaly = Boolean(context.metadata?.locationAnomaly);

    if (actorType === 'rider' && Number.isFinite(riderAgeDays) && riderAgeDays < 7 && highValueOrder && locationAnomaly) {
      scoreState.score += 30;
      scoreState.reasonCodes.add(REASON_CODES.RIDER_COLD_START_LOCATION_ANOMALY);
      scoreState.reasonDetails.riderColdStart = { riderAgeDays, highValueOrder, locationAnomaly };
    }
  }
};

const decide = async ({ actionType, actorType, actorId, context }) => {
  await ensureFeatureDefinitions().catch(() => null);

  const policy = await getActivePolicy();
  const validation = validateContext({ actionType, context });

  const scoreState = {
    score: 0,
    reasonCodes: new Set(),
    reasonDetails: {},
  };

  if (!validation.valid) {
    scoreState.reasonCodes.add(REASON_CODES.CONTEXT_REQUIRED_MISSING);
    scoreState.reasonDetails.missing = validation.missing;

    if (validation.rule.missingRequired === 'fail_closed') {
      const decision = DECISIONS.BLOCK;
      return {
        decision,
        score: 100,
        challengeType: null,
        reasonCodes: Array.from(scoreState.reasonCodes),
        reasonDetails: scoreState.reasonDetails,
        policy,
        validation,
      };
    }

    if (validation.rule.missingRequired === 'fail_open_stepup_on_velocity') {
      const velocitySubject = actorId || context?.ipHash || 'unknown';
      const velocityCount = await velocityCounter({
        key: `grabgo:fraud:velocity:missing_context:${actionType}:${velocitySubject}`,
        ttlSeconds: 3600,
      });

      if (velocityCount >= 10) {
        scoreState.reasonCodes.add(REASON_CODES.MEDIUM_RISK_SCORE);
        scoreState.reasonDetails.missingContextVelocityCount = velocityCount;
        return {
          decision: DECISIONS.STEP_UP,
          score: 45,
          challengeType: CHALLENGE_TYPES.OTP,
          reasonCodes: Array.from(scoreState.reasonCodes),
          reasonDetails: scoreState.reasonDetails,
          policy,
          validation,
        };
      }
    }

    if (validation.rule.missingRequired === 'fail_open_queue_anomaly') {
      scoreState.reasonDetails.anomalyQueued = true;
    }

    return {
      decision: DECISIONS.ALLOW_DEGRADED,
      score: 0,
      challengeType: null,
      reasonCodes: Array.from(scoreState.reasonCodes),
      reasonDetails: scoreState.reasonDetails,
      policy,
      validation,
    };
  }

  const allowlistHit = await checkSignalHit({ actorType, actorId, signalType: 'allowlist' });
  if (allowlistHit) {
    scoreState.reasonCodes.add(REASON_CODES.ALLOWLIST_MATCH);
  }

  const denylistHit = await checkSignalHit({ actorType, actorId, signalType: 'denylist' });
  if (denylistHit) {
    scoreState.reasonCodes.add(REASON_CODES.DENYLIST_MATCH_CONFIRMED);
    scoreState.score = 100;
  }

  if (context.metadata?.paymentMetadataMismatch === true) {
    scoreState.reasonCodes.add(REASON_CODES.PAYMENT_METADATA_MISMATCH);
    scoreState.score = 100;
  }

  if (context.metadata?.webhookSignatureValid === false) {
    scoreState.reasonCodes.add(REASON_CODES.PAYMENT_WEBHOOK_SIGNATURE_INVALID);
    scoreState.score = 100;
  }

  await applyVelocitySignals({ actionType, actorType, actorId, context, scoreState });
  await applyColdStartSignals({ actionType, actorType, actorId, context, scoreState, policy });

  if (policy.rule_toggles?.graph_checks !== false) {
    await applyGraphSignals({ actorType, actorId, context, scoreState });
  }

  const decision = allowlistHit
    ? DECISIONS.ALLOW
    : resolveDecision({
    score: scoreState.score,
    policy,
    reasonCodes: Array.from(scoreState.reasonCodes),
  });

  if (decision === DECISIONS.STEP_UP) {
    scoreState.reasonCodes.add(REASON_CODES.MEDIUM_RISK_SCORE);
  }
  if (decision === DECISIONS.BLOCK) {
    scoreState.reasonCodes.add(REASON_CODES.HIGH_RISK_SCORE);
  }

  const challengeType = decision === DECISIONS.STEP_UP
    ? ([ACTION_TYPES.PAYMENT_CLIENT_CONFIRM, ACTION_TYPES.ORDER_CREATE].includes(actionType)
      ? CHALLENGE_TYPES.PAYMENT_REAUTH
      : CHALLENGE_TYPES.OTP)
    : null;

  return {
    decision,
    score: Math.min(100, Math.max(0, Number(scoreState.score || 0))),
    challengeType,
    reasonCodes: Array.from(scoreState.reasonCodes),
    reasonDetails: scoreState.reasonDetails,
    policy,
    validation,
  };
};

const evaluate = async ({ actionType, actorType, actorId, context }) => {
  const startedAt = Date.now();
  const result = await decide({ actionType, actorType, actorId, context });
  let finalResult = { ...result };

  const shadowMode = process.env.FRAUD_SHADOW_MODE !== 'false';

  if (finalResult.decision === DECISIONS.STEP_UP && actorType && actorId) {
    const policyCaps = finalResult.policy?.challenge_caps || {};
    const perActionPer24h = Number(policyCaps.perActionPer24h || 1);
    const totalPer24h = Number(policyCaps.totalPer24h || 3);
    const hasHardOverride = (finalResult.reasonCodes || []).some((code) => HARD_BLOCK_REASON_CODES.has(code));

    const capCheck = await checkChallengeCaps({
      actorType,
      actorId,
      actionType,
      perActionPer24h,
      totalPer24h,
    }).catch(() => null);

    if (capCheck && !capCheck.allowed && !hasHardOverride) {
      finalResult = {
        ...finalResult,
        decision: DECISIONS.ALLOW_DEGRADED,
        challengeType: null,
        reasonCodes: Array.from(
          new Set([...(finalResult.reasonCodes || []), REASON_CODES.CHALLENGE_CAP_REACHED])
        ),
        reasonDetails: {
          ...(finalResult.reasonDetails || {}),
          challengeCap: {
            currentPerAction: capCheck.currentPerAction,
            currentTotal: capCheck.currentTotal,
          },
        },
      };
    }
  }

  await recordDecision({
    actorType,
    actorId,
    actionType,
    score: finalResult.score,
    decision: finalResult.decision,
    reasonCodes: finalResult.reasonCodes,
    reasonDetails: finalResult.reasonDetails,
    challengeType: finalResult.challengeType,
    policy: finalResult.policy,
    context,
    shadowMode,
  }).catch(() => null);

  await upsertProfile({
    actorType,
    actorId,
    riskScore: finalResult.score,
    riskLevel: scoreToRiskLevel(finalResult.score),
    featureSnapshot: {
      requestLatencyMs: Date.now() - startedAt,
      actionType,
    },
    graphSnapshot: finalResult.reasonDetails?.sharedEntity || null,
  }).catch(() => null);

  await enqueueOutboxEvent({
    eventType: 'fraud.decision.created',
    aggregateType: actorType,
    aggregateId: actorId,
    payload: {
      actionType,
      decision: finalResult.decision,
      score: finalResult.score,
      reasonCodes: finalResult.reasonCodes,
      contextHash: context.contextHash,
      policyVersion: finalResult.policy.version,
      policyChecksum: finalResult.policy.checksum,
      evaluatedAt: new Date().toISOString(),
    },
    idempotencyKey: `fraud.decision:${context.contextHash}`,
    eventId: context.requestId || context.contextHash,
  }).catch(() => null);

  if (
    !finalResult.validation?.valid &&
    finalResult.validation?.rule?.missingRequired === 'fail_open_queue_anomaly'
  ) {
    await createCase({
      actorType,
      actorId,
      severity: 'p3',
      queue: 'anomaly_review',
      openedReason: 'Incomplete fraud context routed to anomaly review queue',
      reasonCodes: finalResult.reasonCodes,
      evidence: {
        actionType,
        missing: finalResult.validation?.missing || [],
        contextHash: context.contextHash,
      },
    }).catch(() => null);
  }

  if (finalResult.decision === DECISIONS.BLOCK) {
    await createCase({
      actorType,
      actorId,
      severity: finalResult.score >= 90 ? 'p1' : 'p2',
      openedReason: 'Automated fraud block decision',
      reasonCodes: finalResult.reasonCodes,
      evidence: {
        actionType,
        score: finalResult.score,
        contextHash: context.contextHash,
      },
    }).catch(() => null);
  }

  return {
    ...finalResult,
    latencyMs: Date.now() - startedAt,
    shadowMode,
  };
};

module.exports = {
  decide,
  evaluate,
};
