/**
 * Unit Tests — Rider Streak Engine
 *
 * Tests streak continuity logic and reward threshold constants.
 */

const {
  checkStreakContinuity,
  STREAK_REWARD_THRESHOLDS,
  MIN_DELIVERIES_FOR_STREAK_DAY,
} = require('../services/rider_streak_engine');

// ────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────

describe('Streak Engine — Constants', () => {
  test('STREAK_REWARD_THRESHOLDS should be in ascending days order', () => {
    for (let i = 1; i < STREAK_REWARD_THRESHOLDS.length; i++) {
      expect(STREAK_REWARD_THRESHOLDS[i].days).toBeGreaterThan(
        STREAK_REWARD_THRESHOLDS[i - 1].days
      );
    }
  });

  test('STREAK_REWARD_THRESHOLDS rewards should increase', () => {
    for (let i = 1; i < STREAK_REWARD_THRESHOLDS.length; i++) {
      expect(STREAK_REWARD_THRESHOLDS[i].baseReward).toBeGreaterThan(
        STREAK_REWARD_THRESHOLDS[i - 1].baseReward
      );
    }
  });

  test('should have at least 3 thresholds', () => {
    expect(STREAK_REWARD_THRESHOLDS.length).toBeGreaterThanOrEqual(3);
  });

  test('each threshold should have days, baseReward, and label', () => {
    for (const t of STREAK_REWARD_THRESHOLDS) {
      expect(t).toHaveProperty('days');
      expect(t).toHaveProperty('baseReward');
      expect(t).toHaveProperty('label');
      expect(typeof t.days).toBe('number');
      expect(typeof t.baseReward).toBe('number');
      expect(typeof t.label).toBe('string');
    }
  });

  test('MIN_DELIVERIES_FOR_STREAK_DAY should be positive', () => {
    expect(MIN_DELIVERIES_FOR_STREAK_DAY).toBeGreaterThan(0);
  });
});

// ────────────────────────────────────────────────────────────────────
// checkStreakContinuity
// ────────────────────────────────────────────────────────────────────

describe('checkStreakContinuity', () => {
  test('returns "broken" when prevDate is null', () => {
    expect(checkStreakContinuity(null, new Date())).toBe('broken');
  });

  test('returns "broken" when prevDate is undefined', () => {
    expect(checkStreakContinuity(undefined, new Date())).toBe('broken');
  });

  test('returns "same_day" for same calendar day', () => {
    const prev = new Date('2026-03-05T08:00:00Z');
    const curr = new Date('2026-03-05T20:00:00Z');
    expect(checkStreakContinuity(prev, curr)).toBe('same_day');
  });

  test('returns "consecutive" for next calendar day', () => {
    const prev = new Date('2026-03-05T23:00:00Z');
    const curr = new Date('2026-03-06T01:00:00Z');
    expect(checkStreakContinuity(prev, curr)).toBe('consecutive');
  });

  test('returns "broken" for gap of 2+ days', () => {
    const prev = new Date('2026-03-05T12:00:00Z');
    const curr = new Date('2026-03-07T12:00:00Z');
    expect(checkStreakContinuity(prev, curr)).toBe('broken');
  });

  test('returns "broken" for gap of a week', () => {
    const prev = new Date('2026-03-01T12:00:00Z');
    const curr = new Date('2026-03-08T12:00:00Z');
    expect(checkStreakContinuity(prev, curr)).toBe('broken');
  });

  test('handles month boundary correctly', () => {
    const prev = new Date('2026-03-31T12:00:00Z');
    const curr = new Date('2026-04-01T12:00:00Z');
    expect(checkStreakContinuity(prev, curr)).toBe('consecutive');
  });

  test('handles year boundary correctly', () => {
    const prev = new Date('2025-12-31T12:00:00Z');
    const curr = new Date('2026-01-01T12:00:00Z');
    expect(checkStreakContinuity(prev, curr)).toBe('consecutive');
  });

  test('handles leap year boundary', () => {
    const prev = new Date('2028-02-28T12:00:00Z');
    const curr = new Date('2028-02-29T12:00:00Z');
    expect(checkStreakContinuity(prev, curr)).toBe('consecutive');
  });

  test('handles string date inputs', () => {
    expect(checkStreakContinuity('2026-03-05T12:00:00Z', '2026-03-06T12:00:00Z'))
      .toBe('consecutive');
  });
});
