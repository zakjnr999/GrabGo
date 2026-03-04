const prisma = require('../../config/prisma');
const cache = require('../../utils/cache');
const hasDelegate = (name) => Boolean(prisma?.[name] && typeof prisma[name] === 'object');

const STREAM_NAME = process.env.FRAUD_EVENT_STREAM || 'fraud.events.v1';
const DLQ_STREAM_NAME = process.env.FRAUD_EVENT_DLQ_STREAM || 'fraud.events.dlq.v1';
const STREAM_MAXLEN = Number(process.env.FRAUD_EVENT_STREAM_MAXLEN || 100000);

const enqueueOutboxEvent = async ({
  eventType,
  aggregateType,
  aggregateId,
  payload,
  idempotencyKey,
  eventId,
}) => {
  if (!eventType || !aggregateType || !aggregateId || !idempotencyKey) {
    throw new Error('Invalid outbox payload');
  }

  const resolvedEventId = eventId || `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  if (!hasDelegate('fraudEventOutbox')) return null;

  try {
    return await prisma.fraudEventOutbox.create({
      data: {
        eventId: resolvedEventId,
        eventType,
        aggregateType,
        aggregateId,
        payload,
        idempotencyKey,
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('Unique constraint')) {
      return null;
    }
    if (String(error.message || '').includes('prisma.fraudEventOutbox')) {
      return null;
    }
    throw error;
  }
};

const publishOutboxBatch = async ({ limit = 100 } = {}) => {
  if (!hasDelegate('fraudEventOutbox')) {
    return { published: 0, failed: 0 };
  }
  let rows;
  try {
    rows = await prisma.fraudEventOutbox.findMany({
      where: {
        publishedAt: null,
        OR: [
          { nextAttemptAt: null },
          { nextAttemptAt: { lte: new Date() } },
        ],
        retryCount: { lt: 10 },
      },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudEventOutbox')) {
      return { published: 0, failed: 0 };
    }
    throw error;
  }

  let published = 0;
  let failed = 0;

  for (const row of rows) {
    try {
      await cache.xadd(
        STREAM_NAME,
        {
          event_id: row.eventId,
          event_type: row.eventType,
          aggregate_type: row.aggregateType,
          aggregate_id: row.aggregateId,
          payload: JSON.stringify(row.payload || {}),
          created_at: row.createdAt.toISOString(),
          idempotency_key: row.idempotencyKey,
        },
        { maxLen: STREAM_MAXLEN, approximate: true }
      );

      await prisma.fraudEventOutbox.update({
        where: { id: row.id },
        data: {
          publishedAt: new Date(),
          lastError: null,
        },
      });
      published += 1;
    } catch (error) {
      failed += 1;
      const retryCount = Number(row.retryCount || 0) + 1;
      const delaySeconds = Math.min(300, 2 ** Math.min(retryCount, 8));
      const nextAttemptAt = new Date(Date.now() + delaySeconds * 1000);
      const reachedMaxRetries = retryCount >= 10;

      if (reachedMaxRetries) {
        await cache.xadd(
          DLQ_STREAM_NAME,
          {
            event_id: row.eventId,
            event_type: row.eventType,
            aggregate_type: row.aggregateType,
            aggregate_id: row.aggregateId,
            payload: JSON.stringify(row.payload || {}),
            error: String(error.message || error),
            failed_at: new Date().toISOString(),
          },
          { maxLen: STREAM_MAXLEN, approximate: true }
        ).catch(() => null);
      }

      await prisma.fraudEventOutbox.update({
        where: { id: row.id },
        data: {
          retryCount,
          nextAttemptAt: reachedMaxRetries ? null : nextAttemptAt,
          lastError: String(error.message || error),
          ...(reachedMaxRetries ? { publishedAt: new Date() } : {}),
        },
      }).catch(() => null);
    }
  }

  return { published, failed };
};

module.exports = {
  STREAM_NAME,
  DLQ_STREAM_NAME,
  enqueueOutboxEvent,
  publishOutboxBatch,
};
