const prisma = require('../../config/prisma');
const hasDelegate = (name) => Boolean(prisma?.[name] && typeof prisma[name] === 'object');

const upsertEdge = async ({
  fromActorType,
  fromActorId,
  edgeType,
  toEntityType,
  toEntityId,
  weight = 1,
  metadata = null,
  seenAt = new Date(),
}) => {
  if (!fromActorType || !fromActorId || !edgeType || !toEntityType || !toEntityId) {
    return null;
  }
  if (!hasDelegate('fraudGraphEdge')) return null;

  try {
    return await prisma.fraudGraphEdge.upsert({
      where: {
        fromActorType_fromActorId_edgeType_toEntityType_toEntityId: {
          fromActorType,
          fromActorId,
          edgeType,
          toEntityType,
          toEntityId,
        },
      },
      update: {
        lastSeenAt: seenAt,
        weight: { increment: Number(weight || 0) },
        ...(metadata ? { metadata } : {}),
      },
      create: {
        fromActorType,
        fromActorId,
        edgeType,
        toEntityType,
        toEntityId,
        weight,
        metadata,
        firstSeenAt: seenAt,
        lastSeenAt: seenAt,
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudGraphEdge')) {
      return null;
    }
    throw error;
  }
};

const saveMetric = async ({ actorType, actorId, metricName, metricWindow, metricValue, computedAt = new Date() }) => {
  if (!hasDelegate('fraudGraphMetric')) return null;
  try {
    return await prisma.fraudGraphMetric.create({
      data: {
        actorType,
        actorId,
        metricName,
        metricWindow,
        metricValue: Number(metricValue || 0),
        computedAt,
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudGraphMetric')) {
      return null;
    }
    throw error;
  }
};

const computeSharedEntityDegree = async ({ edgeType, toEntityType, toEntityId, since }) => {
  if (!hasDelegate('fraudGraphEdge')) return 0;
  try {
    return await prisma.fraudGraphEdge.count({
      where: {
        edgeType,
        toEntityType,
        toEntityId,
        ...(since ? { lastSeenAt: { gte: since } } : {}),
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudGraphEdge')) {
      return 0;
    }
    throw error;
  }
};

module.exports = {
  upsertEdge,
  saveMetric,
  computeSharedEntityDegree,
};
