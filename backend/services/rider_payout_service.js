const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');
const { LEVEL_MULTIPLIERS } = require('./rider_score_engine');
const { getWeeklyWindowKey } = require('./rider_quest_engine');

// ── Withdrawal Policy by Partner Level ──
// Free instant withdrawal quotas per week, and instant withdrawal fee
const WITHDRAWAL_POLICY = {
  L1: { freeInstantQuota: 0, instantFee: 2.0, weeklyAutoEnabled: false },
  L2: { freeInstantQuota: 1, instantFee: 2.0, weeklyAutoEnabled: true },
  L3: { freeInstantQuota: 3, instantFee: 1.5, weeklyAutoEnabled: true },
  L4: { freeInstantQuota: 5, instantFee: 1.0, weeklyAutoEnabled: true },
  L5: { freeInstantQuota: 999, instantFee: 0.0, weeklyAutoEnabled: true }, // Unlimited free
};

// Minimum withdrawal amount
const MIN_WITHDRAWAL_AMOUNT = 5.0; // GHS

/**
 * Get the Monday 00:00:00 UTC for the current week.
 */
const getWeekStartDate = (date = new Date()) => {
  const d = new Date(date);
  d.setUTCHours(0, 0, 0, 0);
  const day = d.getUTCDay();
  const diff = (day === 0 ? -6 : 1) - day; // Monday = 1
  d.setUTCDate(d.getUTCDate() + diff);
  return d;
};

/**
 * Get or create the withdrawal allowance for a rider this week.
 *
 * @param {string} riderId
 * @param {string} partnerLevel
 * @returns {Promise<Object>}
 */
const getOrCreateWeeklyAllowance = async (riderId, partnerLevel = 'L1') => {
  const weekStart = getWeekStartDate();
  const policy = WITHDRAWAL_POLICY[partnerLevel] || WITHDRAWAL_POLICY.L1;

  let allowance = await prisma.riderWithdrawalAllowance.findUnique({
    where: { riderId_weekStartAt: { riderId, weekStartAt: weekStart } },
  });

  if (!allowance) {
    allowance = await prisma.riderWithdrawalAllowance.create({
      data: {
        riderId,
        weekStartAt: weekStart,
        freeInstantUsed: 0,
        freeInstantQuota: policy.freeInstantQuota,
      },
    });
  }

  return allowance;
};

/**
 * Calculate withdrawal fee for an instant withdrawal request.
 *
 * @param {string} riderId
 * @param {string} partnerLevel
 * @returns {Promise<{fee: number, isFree: boolean, freeRemaining: number, totalQuota: number}>}
 */
const calculateWithdrawalFee = async (riderId, partnerLevel = 'L1') => {
  const policy = WITHDRAWAL_POLICY[partnerLevel] || WITHDRAWAL_POLICY.L1;
  const allowance = await getOrCreateWeeklyAllowance(riderId, partnerLevel);

  const freeRemaining = Math.max(0, allowance.freeInstantQuota - allowance.freeInstantUsed);
  const isFree = freeRemaining > 0;

  return {
    fee: isFree ? 0 : policy.instantFee,
    isFree,
    freeRemaining,
    totalQuota: allowance.freeInstantQuota,
    freeUsed: allowance.freeInstantUsed,
  };
};

/**
 * Record an instant withdrawal (update allowance counter).
 *
 * @param {string} riderId
 * @param {string} partnerLevel
 */
const recordInstantWithdrawal = async (riderId, partnerLevel = 'L1') => {
  const allowance = await getOrCreateWeeklyAllowance(riderId, partnerLevel);

  if (allowance.freeInstantUsed < allowance.freeInstantQuota) {
    await prisma.riderWithdrawalAllowance.update({
      where: { id: allowance.id },
      data: { freeInstantUsed: { increment: 1 } },
    });
  }
};

/**
 * Create an instant payout request.
 *
 * @param {Object} params
 * @param {string} params.riderId
 * @param {number} params.amount
 * @param {string} params.method - 'bank_account' | 'mtn_mobile_money' | 'vodafone_cash'
 * @param {Object} [params.accountSnapshot]
 * @returns {Promise<Object>} Payout request
 */
const createInstantPayoutRequest = async ({ riderId, amount, method, accountSnapshot }) => {
  // Get partner level
  let partnerLevel = 'L1';
  const profile = await prisma.riderPartnerProfile.findUnique({
    where: { riderId },
    select: { partnerLevel: true },
  });
  if (profile) partnerLevel = profile.partnerLevel;

  // Calculate fee
  const feeInfo = await calculateWithdrawalFee(riderId, partnerLevel);
  const fee = feeInfo.fee;
  const netAmount = Math.round((amount - fee) * 100) / 100;

  if (netAmount < MIN_WITHDRAWAL_AMOUNT) {
    throw new Error(`Net amount after fee (GHS ${netAmount}) is below minimum (GHS ${MIN_WITHDRAWAL_AMOUNT})`);
  }

  const payoutRequest = await prisma.riderPayoutRequest.create({
    data: {
      riderId,
      amount,
      fee,
      netAmount,
      payoutType: 'instant',
      status: 'pending',
      method,
      accountSnapshot: accountSnapshot || undefined,
    },
  });

  // Record the instant withdrawal usage
  await recordInstantWithdrawal(riderId, partnerLevel);

  // Update lastWithdrawalAt on wallet
  await prisma.riderWallet.updateMany({
    where: { userId: riderId },
    data: { lastWithdrawalAt: new Date() },
  });

  console.log(
    `[Payout] Instant request: rider=${riderId}, amount=GHS ${amount}, fee=GHS ${fee}, net=GHS ${netAmount}`
  );

  return payoutRequest;
};

/**
 * Process weekly auto-payouts for all eligible riders.
 * Pays out 'available' incentive ledger entries to riders with weekly_auto enabled.
 *
 * @returns {Promise<Object>} Summary
 */
const processWeeklyAutoPayouts = async () => {
  // Get riders who have available (budget-approved) incentives
  const ridersWithAvailable = await prisma.riderIncentiveLedger.groupBy({
    by: ['riderId'],
    where: { status: 'available' },
    _sum: { finalAmount: true },
  });

  let payoutsCreated = 0;
  let totalPaidOut = 0;

  for (const group of ridersWithAvailable) {
    const riderId = group.riderId;
    const totalAvailable = group._sum.finalAmount || 0;

    if (totalAvailable < MIN_WITHDRAWAL_AMOUNT) continue;

    // Check rider's partner level for weekly auto eligibility
    let partnerLevel = 'L1';
    const profile = await prisma.riderPartnerProfile.findUnique({
      where: { riderId },
      select: { partnerLevel: true },
    });
    if (profile) partnerLevel = profile.partnerLevel;

    const policy = WITHDRAWAL_POLICY[partnerLevel] || WITHDRAWAL_POLICY.L1;
    if (!policy.weeklyAutoEnabled) continue;

    // Create payout request
    const netAmount = Math.round(totalAvailable * 100) / 100;
    const payoutRequest = await prisma.riderPayoutRequest.create({
      data: {
        riderId,
        amount: totalAvailable,
        fee: 0,
        netAmount,
        payoutType: 'weekly_auto',
        status: 'pending',
        method: null, // Will use rider's default payout method
      },
    });

    // Mark ledger entries as paid_out
    await prisma.riderIncentiveLedger.updateMany({
      where: {
        riderId,
        status: 'available',
      },
      data: {
        status: 'paid_out',
        settledAt: new Date(),
      },
    });

    // Credit rider wallet with incentive earnings
    try {
      let wallet = await prisma.riderWallet.findUnique({
        where: { userId: riderId },
      });

      if (!wallet) {
        wallet = await prisma.riderWallet.create({
          data: { userId: riderId },
        });
      }

      await prisma.riderWallet.update({
        where: { id: wallet.id },
        data: {
          balance: { increment: netAmount },
          totalEarnings: { increment: netAmount },
        },
      });

      // Create a transaction record
      await prisma.transaction.create({
        data: {
          walletId: wallet.id,
          userId: riderId,
          amount: netAmount,
          type: 'incentive',
          description: `Weekly incentive payout (${getWeeklyWindowKey()})`,
          referenceId: payoutRequest.id,
          status: 'completed',
        },
      });

      // Update payout as completed
      await prisma.riderPayoutRequest.update({
        where: { id: payoutRequest.id },
        data: {
          status: 'completed',
          processedAt: new Date(),
        },
      });

      // Non-blocking notification
      const { notifyIncentivePayout } = require('./rider_incentive_notifications');
      notifyIncentivePayout(riderId, netAmount, 'weekly_auto').catch(() => {});

      payoutsCreated++;
      totalPaidOut += netAmount;
    } catch (err) {
      console.error(`[Payout] Failed to credit wallet for rider ${riderId}:`, err.message);

      // Mark payout as failed
      await prisma.riderPayoutRequest.update({
        where: { id: payoutRequest.id },
        data: {
          status: 'failed',
          failureReason: err.message,
        },
      });
    }
  }

  if (payoutsCreated > 0) {
    console.log(
      `[Payout] Weekly auto-payout complete: ${payoutsCreated} riders, total GHS ${totalPaidOut.toFixed(2)}`
    );
  }

  return { payoutsCreated, totalPaidOut: Math.round(totalPaidOut * 100) / 100 };
};

/**
 * Get withdrawal policy info for a rider (for app display).
 *
 * @param {string} riderId
 * @returns {Promise<Object>}
 */
const getWithdrawalPolicyInfo = async (riderId) => {
  let partnerLevel = 'L1';
  const profile = await prisma.riderPartnerProfile.findUnique({
    where: { riderId },
    select: { partnerLevel: true },
  });
  if (profile) partnerLevel = profile.partnerLevel;

  const policy = WITHDRAWAL_POLICY[partnerLevel] || WITHDRAWAL_POLICY.L1;
  const feeInfo = await calculateWithdrawalFee(riderId, partnerLevel);

  return {
    partnerLevel,
    minWithdrawalAmount: MIN_WITHDRAWAL_AMOUNT,
    instantWithdrawal: {
      fee: feeInfo.fee,
      isFree: feeInfo.isFree,
      freeRemaining: feeInfo.freeRemaining,
      freeUsed: feeInfo.freeUsed,
      totalQuota: feeInfo.totalQuota,
      standardFee: policy.instantFee,
    },
    weeklyAuto: {
      enabled: policy.weeklyAutoEnabled,
    },
    allLevelPolicies: Object.entries(WITHDRAWAL_POLICY).map(([level, p]) => ({
      level,
      freeInstantQuota: p.freeInstantQuota,
      instantFee: p.instantFee,
      weeklyAutoEnabled: p.weeklyAutoEnabled,
    })),
  };
};

module.exports = {
  // Core
  createInstantPayoutRequest,
  processWeeklyAutoPayouts,
  calculateWithdrawalFee,
  recordInstantWithdrawal,

  // Display
  getWithdrawalPolicyInfo,
  getOrCreateWeeklyAllowance,

  // Constants
  WITHDRAWAL_POLICY,
  MIN_WITHDRAWAL_AMOUNT,
};
