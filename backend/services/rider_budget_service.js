const prisma = require('../config/prisma');
const { getDailyWindowKey, getWeeklyWindowKey } = require('./rider_quest_engine');
const { createScopedLogger } = require('../utils/logger');
const console = createScopedLogger('rider_budget_service');

// ── Default Budget Caps (GHS) ──
// Can be overridden via env: BUDGET_CAP_DAILY, BUDGET_CAP_WEEKLY, BUDGET_CAP_MONTHLY
const DEFAULT_CAPS = {
  daily: Number(process.env.BUDGET_CAP_DAILY) || 5000,
  weekly: Number(process.env.BUDGET_CAP_WEEKLY) || 25000,
  monthly: Number(process.env.BUDGET_CAP_MONTHLY) || 80000,
};

/**
 * Get the monthly window key.
 * @param {Date} [date=new Date()]
 * @returns {string} e.g. "2026-03"
 */
const getMonthlyWindowKey = (date = new Date()) => {
  return date.toISOString().slice(0, 7);
};

/**
 * Get the start/end dates for a budget window.
 */
const getWindowDates = (windowType, windowKey) => {
  if (windowType === 'daily') {
    const startsAt = new Date(windowKey + 'T00:00:00Z');
    const endsAt = new Date(startsAt.getTime() + 24 * 60 * 60 * 1000);
    return { startsAt, endsAt };
  }

  if (windowType === 'weekly') {
    // windowKey = "2026-W10" → compute Monday of that ISO week
    const [yearStr, weekStr] = windowKey.split('-W');
    const year = parseInt(yearStr);
    const week = parseInt(weekStr);
    // Jan 4 is always in ISO week 1
    const jan4 = new Date(Date.UTC(year, 0, 4));
    const dayOfWeek = jan4.getUTCDay() || 7; // 1=Mon, 7=Sun
    const monday = new Date(jan4.getTime() + ((week - 1) * 7 + 1 - dayOfWeek) * 24 * 60 * 60 * 1000);
    const sunday = new Date(monday.getTime() + 7 * 24 * 60 * 60 * 1000);
    return { startsAt: monday, endsAt: sunday };
  }

  if (windowType === 'monthly') {
    // windowKey = "2026-03"
    const [yearStr, monthStr] = windowKey.split('-');
    const year = parseInt(yearStr);
    const month = parseInt(monthStr) - 1;
    const startsAt = new Date(Date.UTC(year, month, 1));
    const endsAt = new Date(Date.UTC(year, month + 1, 1));
    return { startsAt, endsAt };
  }

  throw new Error(`Unknown windowType: ${windowType}`);
};

/**
 * Get or create a budget window for the given type and key.
 *
 * @param {string} windowType - 'daily' | 'weekly' | 'monthly'
 * @param {string} windowKey
 * @returns {Promise<Object>} Budget window record
 */
const getOrCreateBudgetWindow = async (windowType, windowKey) => {
  let window = await prisma.incentiveBudgetWindow.findUnique({
    where: { windowType_windowKey: { windowType, windowKey } },
  });

  if (!window) {
    const { startsAt, endsAt } = getWindowDates(windowType, windowKey);
    const capAmount = DEFAULT_CAPS[windowType] || DEFAULT_CAPS.daily;

    window = await prisma.incentiveBudgetWindow.create({
      data: {
        windowType,
        windowKey,
        startsAt,
        endsAt,
        capAmount,
        spentAmount: 0,
        status: 'active',
      },
    });
  }

  return window;
};

/**
 * Check if a budget window has capacity for an incentive amount.
 *
 * @param {string} windowType
 * @param {string} windowKey
 * @returns {Promise<{hasCapacity: boolean, remaining: number, capAmount: number, spentAmount: number}>}
 */
const checkBudgetCapacity = async (windowType, windowKey) => {
  const window = await getOrCreateBudgetWindow(windowType, windowKey);

  if (window.status === 'exhausted') {
    return {
      hasCapacity: false,
      remaining: 0,
      capAmount: window.capAmount,
      spentAmount: window.spentAmount,
    };
  }

  const remaining = Math.max(0, window.capAmount - window.spentAmount);

  return {
    hasCapacity: remaining > 0,
    remaining: Math.round(remaining * 100) / 100,
    capAmount: window.capAmount,
    spentAmount: window.spentAmount,
  };
};

/**
 * Approve pending incentive ledger entries against the daily budget.
 * Transitions entries from 'pending_budget' → 'available' (or stays pending if exhausted).
 *
 * This is called periodically (e.g., every 5 minutes or after each delivery batch).
 *
 * @returns {Promise<Object>} Approval summary
 */
const approvePendingIncentives = async () => {
  const now = new Date();
  const dailyKey = getDailyWindowKey(now);
  const weeklyKey = getWeeklyWindowKey(now);

  // Get the daily budget window
  const dailyBudget = await checkBudgetCapacity('daily', dailyKey);

  if (!dailyBudget.hasCapacity) {
    console.log(`[BudgetWindow] Daily budget exhausted for ${dailyKey} (cap=${dailyBudget.capAmount}, spent=${dailyBudget.spentAmount})`);

    // Mark the window as exhausted
    await prisma.incentiveBudgetWindow.updateMany({
      where: { windowType: 'daily', windowKey: dailyKey, status: 'active' },
      data: { status: 'exhausted' },
    });

    return { approved: 0, remaining: 0, exhausted: true };
  }

  // Get pending entries for today's window
  const pendingEntries = await prisma.riderIncentiveLedger.findMany({
    where: {
      status: 'pending_budget',
      windowKey: { in: [dailyKey, weeklyKey] },
    },
    orderBy: { createdAt: 'asc' }, // FIFO: earliest first
  });

  if (pendingEntries.length === 0) {
    return { approved: 0, remaining: dailyBudget.remaining, exhausted: false };
  }

  let totalApproved = 0;
  let approvedCount = 0;
  let remaining = dailyBudget.remaining;

  for (const entry of pendingEntries) {
    if (remaining < entry.finalAmount) {
      // Not enough budget remaining — stop approving
      break;
    }

    await prisma.riderIncentiveLedger.update({
      where: { id: entry.id },
      data: { status: 'available' },
    });

    totalApproved += entry.finalAmount;
    remaining -= entry.finalAmount;
    approvedCount++;
  }

  // Update the budget window spent amount
  if (totalApproved > 0) {
    await prisma.incentiveBudgetWindow.update({
      where: { windowType_windowKey: { windowType: 'daily', windowKey: dailyKey } },
      data: {
        spentAmount: { increment: totalApproved },
        status: remaining <= 0 ? 'exhausted' : 'active',
      },
    });

    console.log(
      `[BudgetWindow] Approved ${approvedCount} incentives totaling GHS ${totalApproved.toFixed(2)} ` +
      `(daily remaining: GHS ${remaining.toFixed(2)})`
    );
  }

  return {
    approved: approvedCount,
    totalAmount: Math.round(totalApproved * 100) / 100,
    remaining: Math.round(remaining * 100) / 100,
    exhausted: remaining <= 0,
  };
};

/**
 * Close budget windows that have expired (endsAt < now).
 *
 * @returns {Promise<number>} Count of closed windows
 */
const closeExpiredBudgetWindows = async () => {
  const now = new Date();

  const result = await prisma.incentiveBudgetWindow.updateMany({
    where: {
      status: { in: ['active', 'exhausted'] },
      endsAt: { lt: now },
    },
    data: { status: 'closed' },
  });

  if (result.count > 0) {
    console.log(`[BudgetWindow] Closed ${result.count} expired budget windows`);
  }

  return result.count;
};

/**
 * Get budget dashboard for admin view.
 *
 * @returns {Promise<Object>}
 */
const getBudgetDashboard = async () => {
  const now = new Date();
  const dailyKey = getDailyWindowKey(now);
  const weeklyKey = getWeeklyWindowKey(now);
  const monthlyKey = getMonthlyWindowKey(now);

  const [daily, weekly, monthly] = await Promise.all([
    getOrCreateBudgetWindow('daily', dailyKey),
    getOrCreateBudgetWindow('weekly', weeklyKey),
    getOrCreateBudgetWindow('monthly', monthlyKey),
  ]);

  const pendingCount = await prisma.riderIncentiveLedger.count({
    where: { status: 'pending_budget' },
  });

  const availableSum = await prisma.riderIncentiveLedger.aggregate({
    where: { status: 'available' },
    _sum: { finalAmount: true },
  });

  return {
    daily: {
      windowKey: dailyKey,
      capAmount: daily.capAmount,
      spentAmount: daily.spentAmount,
      remaining: Math.max(0, daily.capAmount - daily.spentAmount),
      status: daily.status,
      utilizationPercent: Math.round((daily.spentAmount / daily.capAmount) * 100),
    },
    weekly: {
      windowKey: weeklyKey,
      capAmount: weekly.capAmount,
      spentAmount: weekly.spentAmount,
      remaining: Math.max(0, weekly.capAmount - weekly.spentAmount),
      status: weekly.status,
      utilizationPercent: Math.round((weekly.spentAmount / weekly.capAmount) * 100),
    },
    monthly: {
      windowKey: monthlyKey,
      capAmount: monthly.capAmount,
      spentAmount: monthly.spentAmount,
      remaining: Math.max(0, monthly.capAmount - monthly.spentAmount),
      status: monthly.status,
      utilizationPercent: Math.round((monthly.spentAmount / monthly.capAmount) * 100),
    },
    pendingIncentives: pendingCount,
    totalAvailableUnpaid: availableSum._sum.finalAmount || 0,
  };
};

/**
 * Update a budget window cap (admin action).
 *
 * @param {string} windowType
 * @param {string} windowKey
 * @param {number} newCapAmount
 * @returns {Promise<Object>}
 */
const updateBudgetCap = async (windowType, windowKey, newCapAmount) => {
  const window = await getOrCreateBudgetWindow(windowType, windowKey);

  const updated = await prisma.incentiveBudgetWindow.update({
    where: { id: window.id },
    data: {
      capAmount: newCapAmount,
      // If increasing cap and was exhausted, reactivate
      status: newCapAmount > window.spentAmount ? 'active' : window.status,
    },
  });

  return updated;
};

module.exports = {
  // Core operations
  approvePendingIncentives,
  checkBudgetCapacity,
  closeExpiredBudgetWindows,

  // Management
  getOrCreateBudgetWindow,
  updateBudgetCap,
  getBudgetDashboard,

  // Helpers
  getMonthlyWindowKey,
  getWindowDates,
  DEFAULT_CAPS,
};
