const logger = require('../utils/logger');
const { scheduleReferralCleanup } = require('../jobs/referralCleanup');
const { initializeScheduler } = require('../jobs/notification_scheduler');
const { initializeCartAbandonmentJob } = require('../jobs/cart_abandonment');
const { initializeMealNudges } = require('../jobs/meal_nudges');
const { initializeEngagementNudges } = require('../jobs/engagement_nudges');
const reservationExpiryJob = require('../jobs/reservation_expiry');
const { runAutoOfflineJob } = require('../jobs/rider_auto_offline');
const { initializeDeliveryMonitor } = require('../jobs/delivery_monitor');
const { initializePickupAcceptTimeoutJob } = require('../jobs/pickup_accept_timeout');
const { initializePickupReadyExpiryJob } = require('../jobs/pickup_ready_expiry');
const { initializeScheduledOrderReleaseJob } = require('../jobs/scheduled_order_release');
const dispatchRetryQueueJob = require('../jobs/dispatch_retry_queue');
const { startFraudOutboxWorker, stopFraudOutboxWorker } = require('../jobs/fraud_outbox_worker');
const {
  startFraudFeatureRecomputeJob,
  stopFraudFeatureRecomputeJob,
} = require('../jobs/fraud_feature_recompute');
const featureFlags = require('../config/feature_flags');
const { scheduleRiderPartnerRecalc } = require('../jobs/rider_partner_recalc');
const { scheduleIncentiveBudgetApproval } = require('../jobs/incentive_budget_approval');
const { scheduleWeeklyPayout } = require('../jobs/rider_weekly_payout');
const { scheduleLoanDailyRepayment } = require('../jobs/loan_daily_repayment');

let backgroundJobsStarted = false;
let autoOfflineIntervalId = null;
let autoOfflineStartupTimeoutId = null;

const startBackgroundJobs = ({ io = null } = {}) => {
  if (backgroundJobsStarted) {
    return false;
  }

  backgroundJobsStarted = true;

  scheduleReferralCleanup();
  initializeScheduler(io);
  initializeCartAbandonmentJob(io);
  initializeMealNudges(io);
  initializeEngagementNudges(io);
  reservationExpiryJob.start();
  dispatchRetryQueueJob.start();
  initializeDeliveryMonitor();
  initializePickupAcceptTimeoutJob(io);
  initializePickupReadyExpiryJob(io);
  initializeScheduledOrderReleaseJob(io);

  if (featureFlags.isFraudEnabled && featureFlags.isFraudOutboxWorkerEnabled) {
    startFraudOutboxWorker();
    startFraudFeatureRecomputeJob();
  }

  autoOfflineIntervalId = setInterval(() => {
    runAutoOfflineJob().catch((err) => logger.error('auto_offline_job_error', { error: err }));
  }, 5 * 60 * 1000);

  autoOfflineStartupTimeoutId = setTimeout(() => {
    runAutoOfflineJob().catch((err) => logger.error('auto_offline_job_startup_error', { error: err }));
  }, 10000);

  if (featureFlags.isRiderPartnerSystemEnabled || featureFlags.isRiderPartnerShadowMode) {
    scheduleRiderPartnerRecalc();
  }

  if (featureFlags.isRiderIncentivesEnabled) {
    scheduleIncentiveBudgetApproval();
    scheduleWeeklyPayout();
  }

  scheduleLoanDailyRepayment();
  logger.info('background_jobs_started', { ioAttached: Boolean(io) });
  return true;
};

const stopBackgroundJobs = () => {
  if (!backgroundJobsStarted) {
    return;
  }

  backgroundJobsStarted = false;

  if (featureFlags.isFraudEnabled && featureFlags.isFraudOutboxWorkerEnabled) {
    stopFraudOutboxWorker();
    stopFraudFeatureRecomputeJob();
  }

  if (autoOfflineIntervalId) {
    clearInterval(autoOfflineIntervalId);
    autoOfflineIntervalId = null;
  }

  if (autoOfflineStartupTimeoutId) {
    clearTimeout(autoOfflineStartupTimeoutId);
    autoOfflineStartupTimeoutId = null;
  }

  logger.info('background_jobs_stopped_partial');
};

const areBackgroundJobsRunning = () => backgroundJobsStarted;

module.exports = {
  startBackgroundJobs,
  stopBackgroundJobs,
  areBackgroundJobsRunning,
};
