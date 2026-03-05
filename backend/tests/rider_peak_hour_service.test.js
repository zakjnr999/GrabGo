/**
 * Unit Tests — Rider Peak Hour Service
 *
 * Tests peak window configuration, time parsing, active window detection,
 * and schedule display (all pure functions).
 */

const {
  getPeakWindows,
  parseTimeToMinutes,
  getActivePeakWindows,
  getCurrentPeakStatus,
  getPeakHourSchedule,
  DEFAULT_PEAK_WINDOWS,
  MIN_EARNINGS_FOR_PEAK_BONUS,
} = require('../services/rider_peak_hour_service');

// ────────────────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────────────────

describe('Peak Hour — Constants', () => {
  test('DEFAULT_PEAK_WINDOWS should have 4 windows', () => {
    expect(DEFAULT_PEAK_WINDOWS).toHaveLength(4);
  });

  test('each window should have required fields', () => {
    for (const pw of DEFAULT_PEAK_WINDOWS) {
      expect(pw).toHaveProperty('id');
      expect(pw).toHaveProperty('start');
      expect(pw).toHaveProperty('end');
      expect(pw).toHaveProperty('label');
      expect(pw).toHaveProperty('bonusRate');
      expect(pw).toHaveProperty('daysOfWeek');
      expect(Array.isArray(pw.daysOfWeek)).toBe(true);
      expect(pw.bonusRate).toBeGreaterThan(0);
      expect(pw.bonusRate).toBeLessThanOrEqual(1);
    }
  });

  test('bonus rates should be reasonable (5%–50%)', () => {
    for (const pw of DEFAULT_PEAK_WINDOWS) {
      expect(pw.bonusRate).toBeGreaterThanOrEqual(0.05);
      expect(pw.bonusRate).toBeLessThanOrEqual(0.50);
    }
  });

  test('MIN_EARNINGS_FOR_PEAK_BONUS should be positive', () => {
    expect(MIN_EARNINGS_FOR_PEAK_BONUS).toBeGreaterThan(0);
  });
});

// ────────────────────────────────────────────────────────────────────
// parseTimeToMinutes
// ────────────────────────────────────────────────────────────────────

describe('parseTimeToMinutes', () => {
  test('midnight should be 0', () => {
    expect(parseTimeToMinutes('00:00')).toBe(0);
  });

  test('06:30 should be 390', () => {
    expect(parseTimeToMinutes('06:30')).toBe(390);
  });

  test('12:00 should be 720', () => {
    expect(parseTimeToMinutes('12:00')).toBe(720);
  });

  test('23:59 should be 1439', () => {
    expect(parseTimeToMinutes('23:59')).toBe(1439);
  });

  test('18:00 should be 1080', () => {
    expect(parseTimeToMinutes('18:00')).toBe(1080);
  });
});

// ────────────────────────────────────────────────────────────────────
// getPeakWindows
// ────────────────────────────────────────────────────────────────────

describe('getPeakWindows', () => {
  const originalEnv = process.env.PEAK_HOUR_CONFIG;

  afterEach(() => {
    if (originalEnv) {
      process.env.PEAK_HOUR_CONFIG = originalEnv;
    } else {
      delete process.env.PEAK_HOUR_CONFIG;
    }
  });

  test('returns default windows when no env var', () => {
    delete process.env.PEAK_HOUR_CONFIG;
    const windows = getPeakWindows();
    expect(windows).toEqual(DEFAULT_PEAK_WINDOWS);
  });

  test('returns custom windows from env var', () => {
    const custom = [{ id: 'test', start: '10:00', end: '12:00', label: 'Test', bonusRate: 0.5, daysOfWeek: [1] }];
    process.env.PEAK_HOUR_CONFIG = JSON.stringify(custom);
    const windows = getPeakWindows();
    expect(windows).toEqual(custom);
  });

  test('falls back to defaults on invalid JSON', () => {
    process.env.PEAK_HOUR_CONFIG = 'invalid json{{{';
    const windows = getPeakWindows();
    expect(windows).toEqual(DEFAULT_PEAK_WINDOWS);
  });
});

// ────────────────────────────────────────────────────────────────────
// getActivePeakWindows
// ────────────────────────────────────────────────────────────────────

describe('getActivePeakWindows', () => {
  test('returns array', () => {
    const active = getActivePeakWindows();
    expect(Array.isArray(active)).toBe(true);
  });

  test('active windows are subset of all windows', () => {
    const all = getPeakWindows();
    const active = getActivePeakWindows();
    for (const aw of active) {
      expect(all.find(w => w.id === aw.id)).toBeDefined();
    }
  });
});

// ────────────────────────────────────────────────────────────────────
// getCurrentPeakStatus
// ────────────────────────────────────────────────────────────────────

describe('getCurrentPeakStatus', () => {
  test('returns object with isPeakHour and activeWindows', () => {
    const status = getCurrentPeakStatus();
    expect(status).toHaveProperty('isPeakHour');
    expect(status).toHaveProperty('activeWindows');
    expect(typeof status.isPeakHour).toBe('boolean');
    expect(Array.isArray(status.activeWindows)).toBe(true);
  });

  test('isPeakHour is true iff activeWindows is non-empty', () => {
    const status = getCurrentPeakStatus();
    expect(status.isPeakHour).toBe(status.activeWindows.length > 0);
  });
});

// ────────────────────────────────────────────────────────────────────
// getPeakHourSchedule
// ────────────────────────────────────────────────────────────────────

describe('getPeakHourSchedule', () => {
  test('returns array of schedule objects', () => {
    const schedule = getPeakHourSchedule();
    expect(Array.isArray(schedule)).toBe(true);
    expect(schedule.length).toBe(DEFAULT_PEAK_WINDOWS.length);
  });

  test('each schedule entry has expected fields', () => {
    const schedule = getPeakHourSchedule();
    for (const entry of schedule) {
      expect(entry).toHaveProperty('id');
      expect(entry).toHaveProperty('label');
      expect(entry).toHaveProperty('start');
      expect(entry).toHaveProperty('end');
      expect(entry).toHaveProperty('bonusRate');
    }
  });
});
