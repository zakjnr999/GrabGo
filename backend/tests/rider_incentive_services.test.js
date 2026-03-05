/**
 * Unit Tests — Rider Incentive Orchestrator, Budget Service, Payout Service,
 *              and Incentive Notifications
 *
 * Tests pure functions and constants from the remaining services.
 */

// ═══════════════════════════════════════════════════════════════════
// Orchestrator
// ═══════════════════════════════════════════════════════════════════

const { buildSourceRef } = require('../services/rider_incentive_orchestrator');

describe('Orchestrator — buildSourceRef', () => {
  test('produces correct format', () => {
    expect(buildSourceRef('quest', 'abc123', '2026-03-05')).toBe('quest:abc123:2026-03-05');
  });

  test('handles peak_hour source type', () => {
    expect(buildSourceRef('peak_hour', 'lunch:order1', '2026-03-05'))
      .toBe('peak_hour:lunch:order1:2026-03-05');
  });

  test('handles streak source type', () => {
    expect(buildSourceRef('streak', '5', '2026-W10')).toBe('streak:5:2026-W10');
  });

  test('handles milestone source type', () => {
    expect(buildSourceRef('milestone', 'ms_100', '2026-03-05'))
      .toBe('milestone:ms_100:2026-03-05');
  });
});

// ═══════════════════════════════════════════════════════════════════
// Budget Service
// ═══════════════════════════════════════════════════════════════════

const {
  getMonthlyWindowKey,
  getWindowDates,
  DEFAULT_CAPS,
} = require('../services/rider_budget_service');

describe('Budget Service — Constants', () => {
  test('DEFAULT_CAPS should have daily, weekly, monthly', () => {
    expect(DEFAULT_CAPS).toHaveProperty('daily');
    expect(DEFAULT_CAPS).toHaveProperty('weekly');
    expect(DEFAULT_CAPS).toHaveProperty('monthly');
  });

  test('caps should be in ascending order: daily < weekly < monthly', () => {
    expect(DEFAULT_CAPS.daily).toBeLessThan(DEFAULT_CAPS.weekly);
    expect(DEFAULT_CAPS.weekly).toBeLessThan(DEFAULT_CAPS.monthly);
  });

  test('all caps should be positive', () => {
    expect(DEFAULT_CAPS.daily).toBeGreaterThan(0);
    expect(DEFAULT_CAPS.weekly).toBeGreaterThan(0);
    expect(DEFAULT_CAPS.monthly).toBeGreaterThan(0);
  });
});

describe('Budget Service — getMonthlyWindowKey', () => {
  test('returns YYYY-MM format', () => {
    expect(getMonthlyWindowKey(new Date('2026-03-15'))).toBe('2026-03');
  });

  test('handles January', () => {
    expect(getMonthlyWindowKey(new Date('2026-01-01'))).toBe('2026-01');
  });

  test('handles December', () => {
    expect(getMonthlyWindowKey(new Date('2026-12-31'))).toBe('2026-12');
  });

  test('uses current date when no argument', () => {
    const result = getMonthlyWindowKey();
    expect(result).toMatch(/^\d{4}-\d{2}$/);
  });
});

describe('Budget Service — getWindowDates', () => {
  test('daily window returns correct startsAt/endsAt', () => {
    const { startsAt, endsAt } = getWindowDates('daily', '2026-03-05');
    expect(startsAt.toISOString()).toContain('2026-03-05');
    expect(endsAt.getTime()).toBeGreaterThan(startsAt.getTime());
  });

  test('weekly window returns Monday start', () => {
    const { startsAt } = getWindowDates('weekly', '2026-W10');
    expect(startsAt.getUTCDay()).toBe(1); // Monday
  });

  test('monthly window returns first of month', () => {
    const { startsAt } = getWindowDates('monthly', '2026-03');
    expect(startsAt.getUTCDate()).toBe(1);
    expect(startsAt.getUTCMonth()).toBe(2); // March (0-indexed)
  });

  test('endsAt is always after startsAt', () => {
    const types = [
      ['daily', '2026-03-05'],
      ['weekly', '2026-W10'],
      ['monthly', '2026-03'],
    ];
    for (const [type, key] of types) {
      const { startsAt, endsAt } = getWindowDates(type, key);
      expect(endsAt.getTime()).toBeGreaterThan(startsAt.getTime());
    }
  });
});

// ═══════════════════════════════════════════════════════════════════
// Payout Service
// ═══════════════════════════════════════════════════════════════════

const {
  WITHDRAWAL_POLICY,
  MIN_WITHDRAWAL_AMOUNT,
} = require('../services/rider_payout_service');

describe('Payout Service — Constants', () => {
  test('WITHDRAWAL_POLICY has all 5 levels', () => {
    expect(Object.keys(WITHDRAWAL_POLICY)).toEqual(['L1', 'L2', 'L3', 'L4', 'L5']);
  });

  test('L1 should have 0 free instant withdrawals', () => {
    expect(WITHDRAWAL_POLICY.L1.freeInstantQuota).toBe(0);
  });

  test('L5 should have unlimited (999) free instant withdrawals', () => {
    expect(WITHDRAWAL_POLICY.L5.freeInstantQuota).toBe(999);
  });

  test('L5 should have 0 instant fee', () => {
    expect(WITHDRAWAL_POLICY.L5.instantFee).toBe(0);
  });

  test('free instant quota should increase with level', () => {
    const levels = ['L1', 'L2', 'L3', 'L4', 'L5'];
    for (let i = 1; i < levels.length; i++) {
      expect(WITHDRAWAL_POLICY[levels[i]].freeInstantQuota)
        .toBeGreaterThanOrEqual(WITHDRAWAL_POLICY[levels[i - 1]].freeInstantQuota);
    }
  });

  test('instant fee should decrease with level', () => {
    const levels = ['L1', 'L2', 'L3', 'L4', 'L5'];
    for (let i = 1; i < levels.length; i++) {
      expect(WITHDRAWAL_POLICY[levels[i]].instantFee)
        .toBeLessThanOrEqual(WITHDRAWAL_POLICY[levels[i - 1]].instantFee);
    }
  });

  test('L1 should not have weekly auto enabled', () => {
    expect(WITHDRAWAL_POLICY.L1.weeklyAutoEnabled).toBe(false);
  });

  test('L2-L5 should have weekly auto enabled', () => {
    for (const level of ['L2', 'L3', 'L4', 'L5']) {
      expect(WITHDRAWAL_POLICY[level].weeklyAutoEnabled).toBe(true);
    }
  });

  test('MIN_WITHDRAWAL_AMOUNT should be positive', () => {
    expect(MIN_WITHDRAWAL_AMOUNT).toBeGreaterThan(0);
  });
});

// ═══════════════════════════════════════════════════════════════════
// Notification Service
// ═══════════════════════════════════════════════════════════════════

const {
  LEVEL_LABELS,
  LEVEL_EMOJI,
} = require('../services/rider_incentive_notifications');

describe('Incentive Notifications — Constants', () => {
  test('LEVEL_LABELS has all 5 levels', () => {
    expect(Object.keys(LEVEL_LABELS)).toEqual(['L1', 'L2', 'L3', 'L4', 'L5']);
  });

  test('each label is a non-empty string', () => {
    for (const label of Object.values(LEVEL_LABELS)) {
      expect(typeof label).toBe('string');
      expect(label.length).toBeGreaterThan(0);
    }
  });

  test('LEVEL_EMOJI has all 5 levels', () => {
    expect(Object.keys(LEVEL_EMOJI)).toEqual(['L1', 'L2', 'L3', 'L4', 'L5']);
  });

  test('each emoji is a non-empty string', () => {
    for (const emoji of Object.values(LEVEL_EMOJI)) {
      expect(typeof emoji).toBe('string');
      expect(emoji.length).toBeGreaterThan(0);
    }
  });
});
