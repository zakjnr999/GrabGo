const prisma = require('../../config/prisma');
const cache = require('../../utils/cache');
const hasDelegate = (name) => Boolean(prisma?.[name] && typeof prisma[name] === 'object');

const SHORT_WINDOW_TTL = Number(process.env.FRAUD_FEATURE_SHORT_TTL_SECONDS || 120);
const LONG_WINDOW_TTL = Number(process.env.FRAUD_FEATURE_LONG_TTL_SECONDS || 900);

const SHORT_WINDOW_FEATURES = new Set([
  'orders_last_1h',
  'failed_payments_last_10m',
  'promo_attempts_last_1h',
]);

const makeCacheKey = ({ actorType, actorId, featureName, featureVersion }) =>
  `grabgo:fraud:feature:${actorType}:${actorId}:${featureName}:v${featureVersion}`;

const resolveTtl = (featureName) => (SHORT_WINDOW_FEATURES.has(featureName) ? SHORT_WINDOW_TTL : LONG_WINDOW_TTL);

const getFeature = async ({ actorType, actorId, featureName, featureVersion = 1 }) => {
  const key = makeCacheKey({ actorType, actorId, featureName, featureVersion });
  const cached = await cache.get(key);
  if (cached !== null && cached !== undefined) {
    return cached;
  }

  if (!hasDelegate('fraudFeatureSnapshot')) {
    return null;
  }

  try {
    const row = await prisma.fraudFeatureSnapshot.findFirst({
      where: { actorType, actorId, featureName, featureVersion },
      orderBy: { computedAt: 'desc' },
      select: { value: true },
    });
    const value = row?.value ?? null;
    await cache.set(key, value, resolveTtl(featureName));
    return value;
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudFeatureSnapshot')) {
      return null;
    }
    throw error;
  }
};

const setFeature = async ({ actorType, actorId, featureName, featureVersion = 1, value, computedAt = new Date(), expiresAt = null }) => {
  const key = makeCacheKey({ actorType, actorId, featureName, featureVersion });
  await cache.set(key, value, resolveTtl(featureName));

  if (!hasDelegate('fraudFeatureSnapshot')) {
    return value;
  }

  try {
    await prisma.fraudFeatureSnapshot.create({
      data: {
        actorType,
        actorId,
        featureName,
        featureVersion,
        value,
        computedAt,
        expiresAt,
      },
    });
  } catch (error) {
    if (!String(error.message || '').includes('prisma.fraudFeatureSnapshot')) {
      throw error;
    }
  }

  return value;
};

const upsertFeatureDefinition = async ({ featureName, featureVersion = 1, description = null, windowSeconds = null, isActive = true }) => {
  if (!hasDelegate('fraudFeatureDefinition')) {
    return null;
  }
  try {
    return await prisma.fraudFeatureDefinition.upsert({
      where: {
        featureName_featureVersion: {
          featureName,
          featureVersion,
        },
      },
      update: {
        description,
        windowSeconds,
        isActive,
      },
      create: {
        featureName,
        featureVersion,
        description,
        windowSeconds,
        isActive,
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudFeatureDefinition')) {
      return null;
    }
    throw error;
  }
};

const getSnapshot = async ({ actorType, actorId, featureNames = [] }) => {
  const result = {};
  for (const featureName of featureNames) {
    result[featureName] = await getFeature({ actorType, actorId, featureName, featureVersion: 1 });
  }
  return result;
};

module.exports = {
  SHORT_WINDOW_TTL,
  LONG_WINDOW_TTL,
  getFeature,
  setFeature,
  upsertFeatureDefinition,
  getSnapshot,
};
