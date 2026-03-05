const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');

// ── Loan eligibility by partner level ──
const LOAN_POLICY = {
  L1: { eligible: false, maxAmount: 0, interestRate: 0, terms: [] },
  L2: { eligible: true, maxAmount: 300, interestRate: 0.08, terms: [7, 14] },
  L3: { eligible: true, maxAmount: 500, interestRate: 0.06, terms: [7, 14, 30] },
  L4: { eligible: true, maxAmount: 800, interestRate: 0.05, terms: [7, 14, 30] },
  L5: { eligible: true, maxAmount: 1000, interestRate: 0.03, terms: [7, 14, 30] },
};

const MIN_LOAN_AMOUNT = 50; // GHS
const MIN_COMPLETED_DELIVERIES = 20;
const MIN_RATING = 3.5;
const MAX_ACTIVE_LOANS = 1;

/**
 * Get the rider's current partner level.
 */
const getRiderPartnerLevel = async (riderId) => {
  const profile = await prisma.riderPartnerProfile.findUnique({
    where: { riderId },
    select: { partnerLevel: true },
  });
  return profile?.partnerLevel || 'L1';
};

/**
 * Check if a rider is eligible for a loan and return policy info.
 */
const getLoanEligibility = async (riderId) => {
  const partnerLevel = await getRiderPartnerLevel(riderId);
  const policy = LOAN_POLICY[partnerLevel] || LOAN_POLICY.L1;

  // Check for active/pending loans
  const activeLoans = await prisma.riderLoan.count({
    where: {
      riderId,
      status: { in: ['pending', 'approved', 'active'] },
    },
  });

  // Get rider stats
  const rider = await prisma.rider.findFirst({
    where: { userId: riderId },
    select: { totalDeliveries: true, averageRating: true },
  });

  const totalDeliveries = rider?.totalDeliveries || 0;
  const averageRating = rider?.averageRating || 0;

  // Build rejection reasons
  const reasons = [];
  if (!policy.eligible) reasons.push('Your partner level does not qualify for loans. Reach L2 or above.');
  if (activeLoans >= MAX_ACTIVE_LOANS) reasons.push('You already have an active or pending loan.');
  if (totalDeliveries < MIN_COMPLETED_DELIVERIES) reasons.push(`Complete at least ${MIN_COMPLETED_DELIVERIES} deliveries first.`);
  if (averageRating < MIN_RATING) reasons.push(`Maintain a ${MIN_RATING}★ or higher rating.`);

  const isEligible = reasons.length === 0;

  // Get outstanding loan balance
  const outstandingLoan = await prisma.riderLoan.findFirst({
    where: { riderId, status: 'active' },
    select: { remainingBalance: true, id: true },
  });

  return {
    eligible: isEligible,
    reasons,
    partnerLevel,
    maxAmount: isEligible ? policy.maxAmount : 0,
    minAmount: MIN_LOAN_AMOUNT,
    interestRate: policy.interestRate,
    availableTerms: policy.terms,
    activeLoans,
    totalDeliveries,
    averageRating,
    outstandingBalance: outstandingLoan?.remainingBalance || 0,
  };
};

/**
 * Submit a loan application.
 */
const applyForLoan = async ({ riderId, amount, termDays, purpose }) => {
  // Re-check eligibility
  const eligibility = await getLoanEligibility(riderId);

  if (!eligibility.eligible) {
    throw new Error(eligibility.reasons[0] || 'You are not eligible for a loan at this time.');
  }

  if (amount < MIN_LOAN_AMOUNT) {
    throw new Error(`Minimum loan amount is GHS ${MIN_LOAN_AMOUNT}.`);
  }

  if (amount > eligibility.maxAmount) {
    throw new Error(`Maximum loan amount for your level is GHS ${eligibility.maxAmount}.`);
  }

  const policy = LOAN_POLICY[eligibility.partnerLevel] || LOAN_POLICY.L1;
  if (!policy.terms.includes(termDays)) {
    throw new Error(`Invalid repayment term. Available: ${policy.terms.join(', ')} days.`);
  }

  const interestRate = policy.interestRate;
  const interestAmount = Math.round(amount * interestRate * 100) / 100;
  const totalRepayable = Math.round((amount + interestAmount) * 100) / 100;
  const dailyDeduction = Math.round((totalRepayable / termDays) * 100) / 100;

  const loan = await prisma.riderLoan.create({
    data: {
      riderId,
      amount,
      interestRate,
      interestAmount,
      totalRepayable,
      dailyDeduction,
      termDays,
      purpose,
      partnerLevel: eligibility.partnerLevel,
      remainingBalance: totalRepayable,
      status: 'pending',
    },
  });

  console.log(
    `[Loan] Application created: rider=${riderId}, amount=GHS ${amount}, ` +
    `term=${termDays}d, total=GHS ${totalRepayable}, daily=GHS ${dailyDeduction}`
  );

  // Auto-approve for L4+ riders (high trust)
  if (['L4', 'L5'].includes(eligibility.partnerLevel)) {
    return await approveLoan(loan.id);
  }

  return loan;
};

/**
 * Approve a pending loan and disburse funds.
 */
const approveLoan = async (loanId) => {
  const loan = await prisma.riderLoan.findUnique({ where: { id: loanId } });
  if (!loan) throw new Error('Loan not found.');
  if (loan.status !== 'pending') throw new Error('Loan is not in pending status.');

  const now = new Date();
  const repaymentStart = new Date(now);
  repaymentStart.setUTCDate(repaymentStart.getUTCDate() + 1); // Start tomorrow
  repaymentStart.setUTCHours(0, 0, 0, 0);

  const repaymentDue = new Date(repaymentStart);
  repaymentDue.setUTCDate(repaymentDue.getUTCDate() + loan.termDays);

  // Update loan status to active and credit rider wallet
  const [updatedLoan] = await prisma.$transaction([
    prisma.riderLoan.update({
      where: { id: loanId },
      data: {
        status: 'active',
        approvedAt: now,
        disbursedAt: now,
        repaymentStartAt: repaymentStart,
        repaymentDueAt: repaymentDue,
      },
    }),

    // Credit the loan amount to rider wallet
    prisma.riderWallet.upsert({
      where: { userId: loan.riderId },
      create: {
        userId: loan.riderId,
        balance: loan.amount,
        totalEarnings: 0,
      },
      update: {
        balance: { increment: loan.amount },
      },
    }),
  ]);

  // Create a transaction record for the disbursement
  const wallet = await prisma.riderWallet.findUnique({
    where: { userId: loan.riderId },
  });

  if (wallet) {
    await prisma.transaction.create({
      data: {
        walletId: wallet.id,
        userId: loan.riderId,
        amount: loan.amount,
        type: 'bonus',
        description: `Loan disbursement – GHS ${loan.amount} (${loan.termDays}-day term)`,
        referenceId: loanId,
        status: 'completed',
      },
    });
  }

  console.log(
    `[Loan] Approved & disbursed: loan=${loanId}, rider=${loan.riderId}, amount=GHS ${loan.amount}`
  );

  // Non-blocking notification
  try {
    const { createNotification } = require('./notification_service');
    await createNotification({
      userId: loan.riderId,
      type: 'loan_approved',
      title: 'Loan Approved! 💰',
      body: `Your GHS ${loan.amount} loan has been approved and credited to your wallet. Repayment of GHS ${loan.dailyDeduction}/day starts tomorrow.`,
      data: { loanId },
    });
  } catch (_) {}

  return updatedLoan;
};

/**
 * Reject a pending loan.
 */
const rejectLoan = async (loanId, reason = 'Application did not meet approval criteria.') => {
  const loan = await prisma.riderLoan.findUnique({ where: { id: loanId } });
  if (!loan) throw new Error('Loan not found.');
  if (loan.status !== 'pending') throw new Error('Loan is not in pending status.');

  const updated = await prisma.riderLoan.update({
    where: { id: loanId },
    data: {
      status: 'rejected',
      rejectedAt: new Date(),
      rejectionReason: reason,
    },
  });

  // Notify rider
  try {
    const { createNotification } = require('./notification_service');
    await createNotification({
      userId: loan.riderId,
      type: 'loan_rejected',
      title: 'Loan Application Update',
      body: `Your GHS ${loan.amount} loan application was not approved. Reason: ${reason}`,
      data: { loanId },
    });
  } catch (_) {}

  return updated;
};

/**
 * Process daily loan repayments (called by a cron job).
 * Deducts dailyDeduction from rider wallets for active loans.
 */
const processDailyLoanRepayments = async () => {
  const activeLoans = await prisma.riderLoan.findMany({
    where: {
      status: 'active',
      repaymentStartAt: { lte: new Date() },
    },
    include: {
      user: {
        select: {
          riderWallet: { select: { id: true, balance: true } },
        },
      },
    },
  });

  let processed = 0;
  let totalCollected = 0;

  for (const loan of activeLoans) {
    const wallet = loan.user?.riderWallet;
    if (!wallet) continue;

    // Deduct either the daily amount or remaining balance (whichever is smaller)
    const deduction = Math.min(loan.dailyDeduction, loan.remainingBalance);

    // Only deduct if wallet has funds (partial deduction if insufficient)
    const actualDeduction = Math.min(deduction, Math.max(0, wallet.balance));
    if (actualDeduction <= 0) continue;

    try {
      const newRemaining = Math.round((loan.remainingBalance - actualDeduction) * 100) / 100;
      const newTotalRepaid = Math.round((loan.totalRepaid + actualDeduction) * 100) / 100;
      const isFullyRepaid = newRemaining <= 0.01; // Float tolerance

      await prisma.$transaction([
        // Deduct from wallet
        prisma.riderWallet.update({
          where: { id: wallet.id },
          data: { balance: { decrement: actualDeduction } },
        }),

        // Update loan
        prisma.riderLoan.update({
          where: { id: loan.id },
          data: {
            totalRepaid: newTotalRepaid,
            remainingBalance: isFullyRepaid ? 0 : newRemaining,
            status: isFullyRepaid ? 'completed' : 'active',
            completedAt: isFullyRepaid ? new Date() : undefined,
          },
        }),

        // Record repayment
        prisma.riderLoanRepayment.create({
          data: {
            loanId: loan.id,
            riderId: loan.riderId,
            amount: actualDeduction,
            type: 'auto_deduction',
            description: `Daily loan repayment (GHS ${actualDeduction.toFixed(2)})`,
          },
        }),

        // Create wallet transaction
        prisma.transaction.create({
          data: {
            walletId: wallet.id,
            userId: loan.riderId,
            amount: -actualDeduction,
            type: 'penalty', // Using 'penalty' type for deductions
            description: `Loan repayment – GHS ${actualDeduction.toFixed(2)}`,
            referenceId: loan.id,
            status: 'completed',
          },
        }),
      ]);

      processed++;
      totalCollected += actualDeduction;

      if (isFullyRepaid) {
        console.log(`[Loan] Fully repaid: loan=${loan.id}, rider=${loan.riderId}`);
        // Notify rider
        try {
          const { createNotification } = require('./notification_service');
          await createNotification({
            userId: loan.riderId,
            type: 'loan_completed',
            title: 'Loan Fully Repaid! 🎉',
            body: `Your GHS ${loan.amount} loan has been fully repaid. You're eligible to apply for a new loan.`,
            data: { loanId: loan.id },
          });
        } catch (_) {}
      }
    } catch (err) {
      console.error(`[Loan] Repayment failed: loan=${loan.id}, error=${err.message}`);
    }
  }

  if (processed > 0) {
    console.log(`[Loan] Daily repayments: ${processed} loans, GHS ${totalCollected.toFixed(2)} collected`);
  }

  return { processed, totalCollected: Math.round(totalCollected * 100) / 100 };
};

/**
 * Get loan history for a rider.
 */
const getRiderLoans = async (riderId, { status, limit = 20, offset = 0 } = {}) => {
  const where = { riderId };
  if (status) where.status = status;

  const [loans, total] = await Promise.all([
    prisma.riderLoan.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
      include: {
        repayments: {
          orderBy: { createdAt: 'desc' },
          take: 5,
        },
      },
    }),
    prisma.riderLoan.count({ where }),
  ]);

  return { loans, total };
};

/**
 * Get a single loan with full repayment history.
 */
const getLoanDetail = async (loanId, riderId) => {
  const loan = await prisma.riderLoan.findFirst({
    where: { id: loanId, riderId },
    include: {
      repayments: {
        orderBy: { createdAt: 'desc' },
      },
    },
  });

  if (!loan) throw new Error('Loan not found.');
  return loan;
};

module.exports = {
  getLoanEligibility,
  applyForLoan,
  approveLoan,
  rejectLoan,
  processDailyLoanRepayments,
  getRiderLoans,
  getLoanDetail,
  LOAN_POLICY,
};
