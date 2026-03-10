const prisma = require('../config/prisma');
const connectMongoDB = require('../config/mongodb');
const cache = require('../utils/cache');
const { fraudPolicyService } = require('../services/fraud');
const logger = require('../utils/logger');

const bootstrapDependencies = async () => {
  await prisma.ensurePrismaConnected();
  await connectMongoDB();
  await cache.initRedis();

  try {
    await fraudPolicyService.ensureDefaultPolicy();
  } catch (error) {
    logger.error('fraud_policy_bootstrap_failed', { error });
  }
};

const getReadinessReport = async () => {
  const postgres = await prisma.checkHealth();
  const mongo = connectMongoDB.isReady();
  const redis = cache.isRedisConnected();

  return {
    status: postgres && mongo ? 'ok' : 'degraded',
    dependencies: {
      postgres: postgres ? 'ok' : 'error',
      mongodb: mongo ? 'ok' : 'error',
      redis: redis ? 'ok' : 'degraded',
    },
  };
};

module.exports = {
  bootstrapDependencies,
  getReadinessReport,
};
