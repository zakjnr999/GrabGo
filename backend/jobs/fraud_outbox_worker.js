const { publishOutboxBatch } = require('../services/fraud/fraud_event_service');

let intervalRef = null;
let isRunning = false;

const startFraudOutboxWorker = () => {
  if (intervalRef) return;

  const intervalMs = Number(process.env.FRAUD_OUTBOX_POLL_MS || 2000);
  intervalRef = setInterval(async () => {
    if (isRunning) return;
    isRunning = true;
    try {
      const result = await publishOutboxBatch({ limit: Number(process.env.FRAUD_OUTBOX_BATCH_SIZE || 100) });
      if (result?.failed > 0) {
        console.warn(`[FraudOutbox] publish partial failure published=${result.published} failed=${result.failed}`);
      }
    } catch (error) {
      console.error('[FraudOutbox] Worker error:', error.message);
    } finally {
      isRunning = false;
    }
  }, intervalMs);

  console.log(`[FraudOutbox] Worker started (poll=${intervalMs}ms)`);
};

const stopFraudOutboxWorker = () => {
  if (!intervalRef) return;
  clearInterval(intervalRef);
  intervalRef = null;
  isRunning = false;
  console.log('[FraudOutbox] Worker stopped');
};

module.exports = {
  startFraudOutboxWorker,
  stopFraudOutboxWorker,
};
