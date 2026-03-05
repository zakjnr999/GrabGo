/**
 * Unit Tests — Rider Quest Engine
 *
 * Tests window key generation (daily/weekly) and related pure logic.
 */

const {
  getDailyWindowKey,
  getWeeklyWindowKey,
  getWindowKey,
} = require('../services/rider_quest_engine');

// ────────────────────────────────────────────────────────────────────
// getDailyWindowKey
// ────────────────────────────────────────────────────────────────────

describe('getDailyWindowKey', () => {
  test('returns YYYY-MM-DD format', () => {
    const date = new Date('2026-03-05T14:30:00Z');
    expect(getDailyWindowKey(date)).toBe('2026-03-05');
  });

  test('handles midnight boundary', () => {
    const date = new Date('2026-03-05T00:00:00Z');
    expect(getDailyWindowKey(date)).toBe('2026-03-05');
  });

  test('handles end of day', () => {
    const date = new Date('2026-03-05T23:59:59Z');
    expect(getDailyWindowKey(date)).toBe('2026-03-05');
  });

  test('handles new year boundary', () => {
    const date = new Date('2025-12-31T23:59:59Z');
    expect(getDailyWindowKey(date)).toBe('2025-12-31');
  });

  test('handles leap year', () => {
    const date = new Date('2028-02-29T12:00:00Z');
    expect(getDailyWindowKey(date)).toBe('2028-02-29');
  });

  test('uses current date when no argument', () => {
    const result = getDailyWindowKey();
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});

// ────────────────────────────────────────────────────────────────────
// getWeeklyWindowKey
// ────────────────────────────────────────────────────────────────────

describe('getWeeklyWindowKey', () => {
  test('returns YYYY-Wnn format', () => {
    const result = getWeeklyWindowKey(new Date('2026-03-05T12:00:00Z'));
    expect(result).toMatch(/^\d{4}-W\d{2}$/);
  });

  test('Monday and Sunday of same week return same key', () => {
    const monday = getWeeklyWindowKey(new Date('2026-03-02T00:00:00Z')); // Monday
    const sunday = getWeeklyWindowKey(new Date('2026-03-08T23:59:59Z')); // Sunday
    expect(monday).toBe(sunday);
  });

  test('Sunday and next Monday return different keys', () => {
    const sunday = getWeeklyWindowKey(new Date('2026-03-08T23:59:59Z')); // Sunday
    const nextMonday = getWeeklyWindowKey(new Date('2026-03-09T00:00:00Z')); // Next Monday
    expect(sunday).not.toBe(nextMonday);
  });

  test('handles new year week boundary', () => {
    const result = getWeeklyWindowKey(new Date('2026-01-01T12:00:00Z'));
    expect(result).toMatch(/^\d{4}-W\d{2}$/);
  });

  test('week number is zero-padded', () => {
    const result = getWeeklyWindowKey(new Date('2026-01-05T12:00:00Z'));
    const weekNum = result.split('-W')[1];
    expect(weekNum.length).toBe(2);
  });
});

// ────────────────────────────────────────────────────────────────────
// getWindowKey
// ────────────────────────────────────────────────────────────────────

describe('getWindowKey', () => {
  const testDate = new Date('2026-03-05T12:00:00Z');

  test('daily period returns daily format', () => {
    expect(getWindowKey('daily', testDate)).toBe('2026-03-05');
  });

  test('weekly period returns weekly format', () => {
    const result = getWindowKey('weekly', testDate);
    expect(result).toMatch(/^\d{4}-W\d{2}$/);
  });

  test('daily and weekly return different formats', () => {
    const daily = getWindowKey('daily', testDate);
    const weekly = getWindowKey('weekly', testDate);
    expect(daily).not.toBe(weekly);
  });
});
