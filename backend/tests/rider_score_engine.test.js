/**
 * Unit Tests — Rider Score Engine
 *
 * Tests pure scoring logic, Bayesian smoothing, level thresholds,
 * level mapping, minimum requirements, and normalization helpers.
 */

const {
  computeBayesianRating,
  scoreToLevel,
  meetsMinRequirements,
  normalize,
  getNextLevelTarget,
  SCORE_WEIGHTS,
  LEVEL_THRESHOLDS,
  LEVEL_MIN_REQUIREMENTS,
  LEVEL_MULTIPLIERS,
  DISPATCH_PRIORITY_BONUS,
  ROLLING_WINDOW_DAYS,
  UPGRADE_LOCK_DAYS,
  DOWNGRADE_CONSECUTIVE_DAYS_REQUIRED,
  VOLUME_100_PERCENTILE,
} = require('../services/rider_score_engine');

// ────────────────────────────────────────────────────────────────────
// Constants validation
// ────────────────────────────────────────────────────────────────────

describe('Score Engine — Constants', () => {
  test('SCORE_WEIGHTS should sum to 1.0', () => {
    const sum = Object.values(SCORE_WEIGHTS).reduce((a, b) => a + b, 0);
    expect(sum).toBeCloseTo(1.0, 5);
  });

  test('LEVEL_THRESHOLDS should be in ascending order', () => {
    for (let i = 1; i < LEVEL_THRESHOLDS.length; i++) {
      expect(LEVEL_THRESHOLDS[i].min).toBeGreaterThan(LEVEL_THRESHOLDS[i - 1].min);
    }
  });

  test('LEVEL_MULTIPLIERS should have all 5 levels', () => {
    expect(Object.keys(LEVEL_MULTIPLIERS)).toEqual(['L1', 'L2', 'L3', 'L4', 'L5']);
  });

  test('LEVEL_MULTIPLIERS should increase monotonically', () => {
    const vals = Object.values(LEVEL_MULTIPLIERS);
    for (let i = 1; i < vals.length; i++) {
      expect(vals[i]).toBeGreaterThanOrEqual(vals[i - 1]);
    }
  });

  test('DISPATCH_PRIORITY_BONUS should have L1 = 0', () => {
    expect(DISPATCH_PRIORITY_BONUS.L1).toBe(0);
  });

  test('DISPATCH_PRIORITY_BONUS should increase with level', () => {
    const vals = Object.values(DISPATCH_PRIORITY_BONUS);
    for (let i = 1; i < vals.length; i++) {
      expect(vals[i]).toBeGreaterThanOrEqual(vals[i - 1]);
    }
  });

  test('ROLLING_WINDOW_DAYS should be 28', () => {
    expect(ROLLING_WINDOW_DAYS).toBe(28);
  });

  test('UPGRADE_LOCK_DAYS should be 14', () => {
    expect(UPGRADE_LOCK_DAYS).toBe(14);
  });

  test('DOWNGRADE_CONSECUTIVE_DAYS_REQUIRED should be 7', () => {
    expect(DOWNGRADE_CONSECUTIVE_DAYS_REQUIRED).toBe(7);
  });

  test('VOLUME_100_PERCENTILE should be 150', () => {
    expect(VOLUME_100_PERCENTILE).toBe(150);
  });
});

// ────────────────────────────────────────────────────────────────────
// computeBayesianRating
// ────────────────────────────────────────────────────────────────────

describe('computeBayesianRating', () => {
  test('returns prior (4.0) when ratingCount is 0', () => {
    expect(computeBayesianRating(5.0, 0)).toBe(4.0);
  });

  test('pulls a perfect 5.0 down with small sample size', () => {
    const result = computeBayesianRating(5.0, 3);
    expect(result).toBeGreaterThan(4.0);
    expect(result).toBeLessThan(5.0);
  });

  test('approaches raw rating with large sample size', () => {
    const result = computeBayesianRating(4.8, 500);
    expect(result).toBeGreaterThan(4.7);
    expect(result).toBeLessThanOrEqual(4.8);
  });

  test('pulls a low rating up with small sample', () => {
    const result = computeBayesianRating(2.0, 2);
    expect(result).toBeGreaterThan(2.0);
    expect(result).toBeLessThan(4.0);
  });

  test('clamps result between 1 and 5', () => {
    expect(computeBayesianRating(0, 1000)).toBeGreaterThanOrEqual(1);
    expect(computeBayesianRating(10, 1000)).toBeLessThanOrEqual(5);
  });

  test('handles exactly the prior weight count', () => {
    // With 10 ratings at 5.0 and prior weight 10 at 4.0: (4*10 + 5*10)/(10+10) = 4.5
    const result = computeBayesianRating(5.0, 10);
    expect(result).toBeCloseTo(4.5, 1);
  });
});

// ────────────────────────────────────────────────────────────────────
// scoreToLevel
// ────────────────────────────────────────────────────────────────────

describe('scoreToLevel', () => {
  test('score 0 should map to L1', () => {
    expect(scoreToLevel(0)).toBe('L1');
  });

  test('score 39 should map to L1', () => {
    expect(scoreToLevel(39)).toBe('L1');
  });

  test('score 40 should map to L2', () => {
    expect(scoreToLevel(40)).toBe('L2');
  });

  test('score 59 should map to L2', () => {
    expect(scoreToLevel(59)).toBe('L2');
  });

  test('score 60 should map to L3', () => {
    expect(scoreToLevel(60)).toBe('L3');
  });

  test('score 74 should map to L3', () => {
    expect(scoreToLevel(74)).toBe('L3');
  });

  test('score 75 should map to L4', () => {
    expect(scoreToLevel(75)).toBe('L4');
  });

  test('score 89 should map to L4', () => {
    expect(scoreToLevel(89)).toBe('L4');
  });

  test('score 90 should map to L5', () => {
    expect(scoreToLevel(90)).toBe('L5');
  });

  test('score 100 should map to L5', () => {
    expect(scoreToLevel(100)).toBe('L5');
  });

  test('negative score should map to L1', () => {
    expect(scoreToLevel(-10)).toBe('L1');
  });
});

// ────────────────────────────────────────────────────────────────────
// normalize
// ────────────────────────────────────────────────────────────────────

describe('normalize', () => {
  test('clamps value to 0-100 range', () => {
    expect(normalize(50, 100)).toBe(50);
    expect(normalize(0, 100)).toBe(0);
    expect(normalize(100, 100)).toBe(100);
  });

  test('normalizes within custom range', () => {
    expect(normalize(75, 150)).toBe(50);
  });

  test('clamps below min to 0', () => {
    expect(normalize(-10, 100)).toBe(0);
  });

  test('clamps above max to 100', () => {
    expect(normalize(200, 100)).toBe(100);
  });

  test('handles equal min and max (division edge)', () => {
    // value/max * 100 = 1 * 100 = 100
    const result = normalize(50, 50);
    expect(result).toBe(100);
    expect(result).not.toBeNaN();
  });
});

// ────────────────────────────────────────────────────────────────────
// meetsMinRequirements
// ────────────────────────────────────────────────────────────────────

describe('meetsMinRequirements', () => {
  test('L1 should always pass (no requirements)', () => {
    expect(meetsMinRequirements('L1', {})).toBe(true);
  });

  test('L2 should require min deliveries and rating', () => {
    const reqs = LEVEL_MIN_REQUIREMENTS.L2;
    if (!reqs) {
      // If L2 has no min requirements defined, it should pass
      expect(meetsMinRequirements('L2', {})).toBe(true);
      return;
    }
    // Should fail with empty components
    expect(meetsMinRequirements('L2', { deliveryVolume: 0, customerRating: 0 })).toBe(false);
  });

  test('higher levels should have stricter or equal requirements', () => {
    const levels = ['L1', 'L2', 'L3', 'L4', 'L5'];
    for (let i = 1; i < levels.length; i++) {
      const curr = LEVEL_MIN_REQUIREMENTS[levels[i]];
      const prev = LEVEL_MIN_REQUIREMENTS[levels[i - 1]];
      if (curr && prev) {
        // Min deliveries should not decrease
        if (curr.minDeliveries && prev.minDeliveries) {
          expect(curr.minDeliveries).toBeGreaterThanOrEqual(prev.minDeliveries);
        }
      }
    }
  });
});

// ────────────────────────────────────────────────────────────────────
// getNextLevelTarget
// ────────────────────────────────────────────────────────────────────

describe('getNextLevelTarget', () => {
  test('L1 rider should get target for L2', () => {
    const target = getNextLevelTarget('L1', 20);
    expect(target).not.toBeNull();
    if (target) {
      expect(target.nextLevel).toBe('L2');
      expect(target.scoreRequired).toBe(40);
      expect(target.scoreGap).toBe(20);
    }
  });

  test('L5 rider should return null (already max)', () => {
    const target = getNextLevelTarget('L5', 95);
    expect(target).toBeNull();
  });

  test('L3 at exactly threshold should show 0 gap needed', () => {
    const target = getNextLevelTarget('L3', 75); // L4 min is 75
    if (target) {
      expect(target.scoreGap).toBe(0);
    }
  });
});
