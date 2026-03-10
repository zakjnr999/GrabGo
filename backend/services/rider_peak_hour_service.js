const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');
const { LEVEL_MULTIPLIERS } = require('./rider_score_engine');
const { getDailyWindowKey, getWindowKey } = require('./rider_quest_engine');
const { createScopedLogger } = require('../utils/logger');
// Lazy require to break circular dependency with orchestrator
const getOrchestratorHelpers = () => require('./rider_incentive_orchestrator');
const console = createScopedLogger('rider_peak_hour_service');

// ── Peak Hour Configuration ──
// Default peak windows for the Ghana market (Africa/Accra = UTC+0).
// Each window: { start: 'HH:MM', end: 'HH:MM', label, bonusRate }
// bonusRate is a multiplier applied to base delivery earnings as an incentive.
//
// These can be overridden via PEAK_HOUR_CONFIG env (JSON string) for ops flexibility.

const DEFAULT_PEAK_WINDOWS = [
  {
    id: 'morning_rush',
    start: '06:30',
    end: '09:00',
    label: 'Morning Rush',
    bonusRate: 0.15,     // +15% of delivery earnings
    daysOfWeek: [1, 2, 3, 4, 5], // Mon–Fri only
  },
  {
    id: 'lunch_rush',
    start: '11:30',
    end: '14:00',
    label: 'Lunch Rush',
    bonusRate: 0.20,     // +20% of delivery earnings
    daysOfWeek: [0, 1, 2, 3, 4, 5, 6], // Every day
  },
  {
    id: 'dinner_rush',
    start: '18:00',
    end: '21:00',
    label: 'Dinner Rush',
    bonusRate: 0.25,     // +25% of delivery earnings
    daysOfWeek: [0, 1, 2, 3, 4, 5, 6], // Every day
  },
  {
    id: 'weekend_afternoon',
    start: '14:00',
    end: '17:00',
    label: 'Weekend Afternoon',
    bonusRate: 0.10,     // +10% of delivery earnings
    daysOfWeek: [0, 6], // Sat & Sun only
  },
];

// Minimum delivery earnings to qualify for peak bonus (avoid micro-bonuses)
const MIN_EARNINGS_FOR_PEAK_BONUS = 1.0; // GHS

/**
 * Parse peak window config from environment or use defaults.
 *
 * @returns {Array} Peak window definitions
 */
const getPeakWindows = () => {
  if (process.env.PEAK_HOUR_CONFIG) {
    try {
      return JSON.parse(process.env.PEAK_HOUR_CONFIG);
    } catch (err) {
      console.error('[PeakHour] Invalid PEAK_HOUR_CONFIG env, using defaults:', err.message);
    }
  }
  return DEFAULT_PEAK_WINDOWS;
};

/**
 * Parse "HH:MM" to minutes since midnight.
 */
const parseTimeToMinutes = (timeStr) => {
  const [h, m] = timeStr.split(':').map(Number);
  return h * 60 + m;
};

/**
 * Check if a given Date falls within any active peak window.
 * Returns all matching peak windows (a delivery could span two, e.g. end of one + start of another).
 *
 * @param {Date} [deliveredAt=new Date()]
 * @returns {Array} Matching peak windows (may be empty)
 */
const getActivePeakWindows = (deliveredAt = new Date()) => {
  const peakWindows = getPeakWindows();
  const dayOfWeek = deliveredAt.getUTCDay(); // 0=Sun, 6=Sat
  const currentMinutes = deliveredAt.getUTCHours() * 60 + deliveredAt.getUTCMinutes();

  const active = [];
  for (const pw of peakWindows) {
    // Check day-of-week
    if (pw.daysOfWeek && !pw.daysOfWeek.includes(dayOfWeek)) continue;

    const startMin = parseTimeToMinutes(pw.start);
    const endMin = parseTimeToMinutes(pw.end);

    // Handle windows that don't cross midnight
    if (currentMinutes >= startMin && currentMinutes < endMin) {
      active.push(pw);
    }
  }

  return active;
};

/**
 * Check if NOW is within a peak window (for rider app display).
 *
 * @returns {Object} { isPeakHour, activeWindows, nextWindow }
 */
const getCurrentPeakStatus = () => {
  const now = new Date();
  const activeWindows = getActivePeakWindows(now);
  const isPeakHour = activeWindows.length > 0;

  // Find the next upcoming window
  let nextWindow = null;
  if (!isPeakHour) {
    const peakWindows = getPeakWindows();
    const dayOfWeek = now.getUTCDay();
    const currentMinutes = now.getUTCHours() * 60 + now.getUTCMinutes();

    let bestDelta = Infinity;

    for (const pw of peakWindows) {
      // Check today first
      if (pw.daysOfWeek && pw.daysOfWeek.includes(dayOfWeek)) {
        const startMin = parseTimeToMinutes(pw.start);
        if (startMin > currentMinutes) {
          const delta = startMin - currentMinutes;
          if (delta < bestDelta) {
            bestDelta = delta;
            nextWindow = {
              ...pw,
              startsInMinutes: delta,
              startsAt: _minutesToTimeStr(startMin),
            };
          }
        }
      }

      // Check tomorrow
      const tomorrow = (dayOfWeek + 1) % 7;
      if (pw.daysOfWeek && pw.daysOfWeek.includes(tomorrow)) {
        const startMin = parseTimeToMinutes(pw.start);
        const delta = (24 * 60 - currentMinutes) + startMin;
        if (delta < bestDelta) {
          bestDelta = delta;
          nextWindow = {
            ...pw,
            startsInMinutes: delta,
            startsAt: _minutesToTimeStr(startMin),
          };
        }
      }
    }
  }

  return {
    isPeakHour,
    activeWindows: activeWindows.map((w) => ({
      id: w.id,
      label: w.label,
      start: w.start,
      end: w.end,
      bonusRate: w.bonusRate,
      bonusPercent: Math.round(w.bonusRate * 100),
    })),
    nextWindow: nextWindow
      ? {
          id: nextWindow.id,
          label: nextWindow.label,
          start: nextWindow.start,
          end: nextWindow.end,
          bonusRate: nextWindow.bonusRate,
          bonusPercent: Math.round(nextWindow.bonusRate * 100),
          startsInMinutes: nextWindow.startsInMinutes,
        }
      : null,
  };
};

/**
 * Convert minutes since midnight to "HH:MM".
 */
const _minutesToTimeStr = (min) => {
  const h = Math.floor(min / 60) % 24;
  const m = min % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
};

/**
 * Calculate and record peak-hour bonus for a delivery.
 * Called from the incentive orchestrator after delivery settlement.
 *
 * The bonus is: deliveryEarnings × peakBonusRate × partnerLevelMultiplier
 *
 * @param {Object} params
 * @param {string} params.riderId
 * @param {string} params.orderId
 * @param {number} params.deliveryEarnings - The base earnings for this delivery
 * @param {Date}   [params.deliveredAt=new Date()] - When the delivery was completed
 * @param {string} [params.partnerLevel='L1']
 * @returns {Promise<Array>} List of peak bonus ledger entries created
 */
const processPeakHourBonus = async ({
  riderId,
  orderId,
  deliveryEarnings,
  deliveredAt = new Date(),
  partnerLevel = 'L1',
}) => {
  if (!featureFlags.isRiderIncentivesEnabled) return [];
  if (deliveryEarnings < MIN_EARNINGS_FOR_PEAK_BONUS) return [];

  const activeWindows = getActivePeakWindows(deliveredAt);
  if (activeWindows.length === 0) return [];

  const dailyKey = getDailyWindowKey(deliveredAt);
  const levelMultiplier = LEVEL_MULTIPLIERS[partnerLevel] || 1.0;
  const entries = [];

  for (const pw of activeWindows) {
    const baseAmount = Math.round(deliveryEarnings * pw.bonusRate * 100) / 100;
    const finalAmount = Math.round(baseAmount * levelMultiplier * 100) / 100;

    if (finalAmount <= 0) continue;

    const { buildSourceRef, writeLedgerEntry } = getOrchestratorHelpers();
    const sourceRef = buildSourceRef('peak_hour', `${pw.id}:${orderId}`, dailyKey);

    const entry = await writeLedgerEntry({
      riderId,
      sourceType: 'peak_hour',
      sourceRef,
      baseAmount,
      multiplier: levelMultiplier,
      finalAmount,
      windowKey: dailyKey,
      metadata: {
        peakWindowId: pw.id,
        peakLabel: pw.label,
        bonusRate: pw.bonusRate,
        deliveryEarnings,
        orderId,
      },
    });

    if (entry) {
      entries.push(entry);
      console.log(
        `[PeakHour] Rider ${riderId}: +GHS ${finalAmount} peak bonus ` +
        `(${pw.label}, ${Math.round(pw.bonusRate * 100)}% × ${levelMultiplier}x) for order ${orderId}`
      );

      // Non-blocking notification
      const { notifyPeakHourBonus } = require('./rider_incentive_notifications');
      notifyPeakHourBonus(riderId, pw.label, finalAmount).catch(() => {});
    }
  }

  return entries;
};

/**
 * Get all peak windows with schedule info (for rider app "Peak Hours" display).
 *
 * @returns {Object} Full schedule with current status
 */
const getPeakHourSchedule = () => {
  const peakWindows = getPeakWindows();
  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  return peakWindows.map((pw) => ({
    id: pw.id,
    label: pw.label,
    start: pw.start,
    end: pw.end,
    bonusRate: pw.bonusRate,
    bonusPercent: Math.round(pw.bonusRate * 100),
    days: (pw.daysOfWeek || []).map((d) => dayNames[d]),
    daysOfWeek: pw.daysOfWeek || [],
  }));
};

module.exports = {
  // Core
  processPeakHourBonus,
  getActivePeakWindows,
  getCurrentPeakStatus,
  getPeakHourSchedule,

  // Helpers (exported for testing)
  getPeakWindows,
  parseTimeToMinutes,
  DEFAULT_PEAK_WINDOWS,
  MIN_EARNINGS_FOR_PEAK_BONUS,
};
