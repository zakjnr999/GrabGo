const cron = require('node-cron');
const prisma = require('../config/prisma');
const cache = require('../utils/cache');
const featureFlags = require('../config/feature_flags');
const { createScopedLogger } = require('../utils/logger');
const {
  evaluateRiderPartnerLevel,
} = require('../services/rider_score_engine');

const JOB_NAME = 'rider_partner_recalc';
const LOCK_KEY = `job:${JOB_NAME}`;
const LOCK_TTL_SECONDS = 600; // 10-minute lock — generous for large rider pools
const BATCH_SIZE = 50; // Number of riders to process in parallel per batch
const console = createScopedLogger('rider_partner_recalc_job');

let isRunning = false;

/**
 * Fetch all rider IDs that should be recalculated.
 *
 * Targets riders that:
 * - Have an active RiderPartnerProfile already, OR
 * - Have at least 1 completed delivery (auto-enrol into partner system)
 *
 * Returns deduplicated list of rider user IDs.
 */
const getEligibleRiderIds = async () => {
  // Riders who already have a partner profile
  const existingProfiles = await prisma.riderPartnerProfile.findMany({
    select: { riderId: true },
  });
  const profileRiderIds = new Set(existingProfiles.map((p) => p.riderId));

  // Riders who have at least 1 delivery but no partner profile yet
  const ridersWithDeliveries = await prisma.rider.findMany({
    where: {
      totalDeliveries: { gte: 1 },
      user: {
        partnerProfile: null,
      },
    },
    select: { userId: true },
  });
  for (const r of ridersWithDeliveries) {
    profileRiderIds.add(r.userId);
  }

  return Array.from(profileRiderIds);
};

/**
 * Process a batch of riders in parallel.
 *
 * @param {string[]} riderIds
 * @param {boolean} shadowMode - If true, compute scores but suppress level changes
 * @returns {Object} Batch results summary
 */
const processBatch = async (riderIds, shadowMode) => {
  const results = await Promise.allSettled(
    riderIds.map(async (riderId) => {
      try {
        const result = await evaluateRiderPartnerLevel(riderId, {
          forceLevel: false,
        });

        if (shadowMode && result.levelChanged) {
          // In shadow mode, roll back the level change but keep the score.
          // This lets us monitor score distributions without affecting riders.
          await prisma.riderPartnerProfile.update({
            where: { riderId },
            data: {
              partnerLevel: result.previousLevel,
              levelLockedUntil: null,
              consecutiveDaysBelowThreshold: 0,
            },
          });

          // Delete the level history entry created in evaluateRiderPartnerLevel
          if (result.levelHistoryEntry) {
            await prisma.riderLevelHistory.delete({
              where: { id: result.levelHistoryEntry.id },
            }).catch(() => {}); // Safe-fail
          }

          return {
            riderId,
            score: result.scoreResult.partnerScore,
            rawLevel: result.effectiveLevel,
            appliedLevel: result.previousLevel,
            shadow: true,
          };
        }

        return {
          riderId,
          score: result.scoreResult.partnerScore,
          level: result.effectiveLevel,
          changed: result.levelChanged,
          shadow: false,
        };
      } catch (err) {
        console.error(`[${JOB_NAME}] Error processing rider ${riderId}:`, err.message);
        throw err;
      }
    })
  );

  let processed = 0;
  let errors = 0;
  let levelChanges = 0;

  for (const r of results) {
    if (r.status === 'fulfilled') {
      processed++;
      if (r.value.changed) levelChanges++;
    } else {
      errors++;
    }
  }

  return { processed, errors, levelChanges };
};

/**
 * Main recalculation run.
 * Iterates all eligible riders in batches and evaluates partner scores/levels.
 */
const runRecalculation = async () => {
  if (isRunning) {
    console.log(`[${JOB_NAME}] Already running, skipping.`);
    return;
  }

  // Check feature flag
  if (!featureFlags.isRiderPartnerSystemEnabled && !featureFlags.isRiderPartnerShadowMode) {
    return; // System disabled entirely
  }

  let lock = null;
  try {
    lock = await cache.acquireLock(LOCK_KEY, LOCK_TTL_SECONDS);
    if (!lock) {
      console.log(`[${JOB_NAME}] Could not acquire lock, another instance is running.`);
      return;
    }

    isRunning = true;
    const startTime = Date.now();
    const shadowMode = featureFlags.isRiderPartnerShadowMode && !featureFlags.isRiderPartnerSystemEnabled;

    console.log(
      `[${JOB_NAME}] Starting daily recalculation...` +
      (shadowMode ? ' (SHADOW MODE — scores computed, levels NOT applied)' : '')
    );

    const riderIds = await getEligibleRiderIds();
    console.log(`[${JOB_NAME}] Found ${riderIds.length} eligible riders.`);

    if (riderIds.length === 0) {
      console.log(`[${JOB_NAME}] No riders to process.`);
      return;
    }

    let totalProcessed = 0;
    let totalErrors = 0;
    let totalLevelChanges = 0;

    // Process in batches
    for (let i = 0; i < riderIds.length; i += BATCH_SIZE) {
      const batch = riderIds.slice(i, i + BATCH_SIZE);
      const batchResult = await processBatch(batch, shadowMode);

      totalProcessed += batchResult.processed;
      totalErrors += batchResult.errors;
      totalLevelChanges += batchResult.levelChanges;

      // Log progress every 200 riders
      if (totalProcessed % 200 === 0 && totalProcessed > 0) {
        console.log(`[${JOB_NAME}] Progress: ${totalProcessed}/${riderIds.length} riders processed.`);
      }
    }

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(
      `[${JOB_NAME}] Completed in ${elapsed}s. ` +
      `Processed: ${totalProcessed}, Errors: ${totalErrors}, Level changes: ${totalLevelChanges}` +
      (shadowMode ? ' (shadow mode)' : '')
    );
  } catch (err) {
    console.error(`[${JOB_NAME}] Fatal error:`, err);
  } finally {
    isRunning = false;
    if (lock) {
      await cache.releaseLock(lock).catch(() => {});
    }
  }
};

/**
 * Schedule the daily partner recalculation cron.
 * Runs at 02:00 Africa/Accra (GMT+0, no DST).
 */
const scheduleRiderPartnerRecalc = () => {
  // '0 2 * * *' = every day at 02:00
  cron.schedule('0 2 * * *', async () => {
    await runRecalculation();
  }, {
    timezone: 'Africa/Accra',
  });

  console.log(`✅ ${JOB_NAME} job scheduled (daily at 02:00 Africa/Accra)`);
};

module.exports = {
  scheduleRiderPartnerRecalc,
  runRecalculation, // Exported for manual/admin triggering
};
