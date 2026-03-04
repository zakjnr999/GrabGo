const crypto = require('crypto');
const prisma = require('../../config/prisma');
const cache = require('../../utils/cache');
const hasDelegate = (name) => Boolean(prisma?.[name] && typeof prisma[name] === 'object');

const challengeKey = ({ actorType, actorId, actionType, scope }) =>
  `grabgo:fraud:challenge:${scope}:${actorType}:${actorId}:${actionType || 'na'}`;

const hashChallengeCode = (code) => {
  const secret = process.env.FRAUD_CHALLENGE_SECRET || process.env.JWT_SECRET || 'grabgo-fraud-challenge-secret';
  return crypto.createHmac('sha256', secret).update(String(code || '')).digest('hex');
};

const createChallenge = async ({ actorType, actorId, challengeType, actionType = null, metadata = null, expiresAt, challengeCode = null }) => {
  if (!hasDelegate('fraudChallenge')) return null;
  try {
    return await prisma.fraudChallenge.create({
      data: {
        actorType,
        actorId,
        challengeType,
        actionType,
        metadata,
        expiresAt,
        challengeCodeHash: challengeCode ? hashChallengeCode(challengeCode) : null,
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudChallenge')) {
      return null;
    }
    throw error;
  }
};

const getLatestPendingChallenge = async ({ actorType, actorId, challengeType, actionType = null }) => {
  if (!hasDelegate('fraudChallenge')) return null;
  try {
    return await prisma.fraudChallenge.findFirst({
      where: {
        actorType,
        actorId,
        challengeType,
        status: 'pending',
        expiresAt: { gt: new Date() },
        ...(actionType ? { actionType } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudChallenge')) {
      return null;
    }
    throw error;
  }
};

const verifyChallengeCode = async ({ challengeId, code }) => {
  if (!hasDelegate('fraudChallenge')) {
    return { success: false, message: 'Challenge store unavailable' };
  }
  const row = await prisma.fraudChallenge.findUnique({ where: { id: challengeId } });
  if (!row) return { success: false, message: 'Challenge not found' };
  if (row.status !== 'pending') return { success: false, message: 'Challenge not pending' };
  if (row.expiresAt && new Date(row.expiresAt).getTime() <= Date.now()) {
    await prisma.fraudChallenge.update({ where: { id: challengeId }, data: { status: 'expired' } }).catch(() => null);
    return { success: false, message: 'Challenge expired' };
  }

  const inputHash = hashChallengeCode(code);
  if (!row.challengeCodeHash || inputHash !== row.challengeCodeHash) {
    await prisma.fraudChallenge.update({
      where: { id: challengeId },
      data: { failedAttempts: { increment: 1 } },
    }).catch(() => null);
    return { success: false, message: 'Invalid challenge code' };
  }

  await prisma.fraudChallenge.update({
    where: { id: challengeId },
    data: {
      status: 'verified',
      verifiedAt: new Date(),
    },
  });

  return { success: true };
};

const checkChallengeCaps = async ({ actorType, actorId, actionType, perActionPer24h, totalPer24h }) => {
  const perActionKey = challengeKey({ actorType, actorId, actionType, scope: 'action' });
  const totalKey = challengeKey({ actorType, actorId, actionType, scope: 'total' });

  const [perActionCount, totalCount] = await Promise.all([
    cache.get(perActionKey),
    cache.get(totalKey),
  ]);

  const currentPerAction = Number(perActionCount || 0);
  const currentTotal = Number(totalCount || 0);

  return {
    allowed: currentPerAction < perActionPer24h && currentTotal < totalPer24h,
    currentPerAction,
    currentTotal,
  };
};

const incrementChallengeCaps = async ({ actorType, actorId, actionType }) => {
  const perActionKey = challengeKey({ actorType, actorId, actionType, scope: 'action' });
  const totalKey = challengeKey({ actorType, actorId, actionType, scope: 'total' });

  await Promise.all([
    cache.incr(perActionKey, 24 * 60 * 60),
    cache.incr(totalKey, 24 * 60 * 60),
  ]);
};

module.exports = {
  createChallenge,
  getLatestPendingChallenge,
  verifyChallengeCode,
  checkChallengeCaps,
  incrementChallengeCaps,
  hashChallengeCode,
};
