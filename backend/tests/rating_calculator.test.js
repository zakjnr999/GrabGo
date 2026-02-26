const {
  calculateWeightedRating,
  normalizeReviewCount,
  normalizeRatingResponse,
  DEFAULT_GLOBAL_MEAN,
} = require("../utils/rating_calculator");

describe("rating_calculator", () => {
  test("returns global mean when there are no ratings", () => {
    const value = calculateWeightedRating(5, 0);
    expect(value).toBe(DEFAULT_GLOBAL_MEAN);
  });

  test("penalizes low-sample high ratings", () => {
    const lowSample = calculateWeightedRating(5, 3);
    expect(lowSample).toBeLessThan(5);
    expect(lowSample).toBeGreaterThan(DEFAULT_GLOBAL_MEAN);
  });

  test("approaches raw rating for high sample size", () => {
    const highSample = calculateWeightedRating(4.8, 500);
    expect(highSample).toBeGreaterThanOrEqual(4.7);
    expect(highSample).toBeLessThanOrEqual(4.8);
  });

  test("normalizes review count to non-negative integer", () => {
    expect(normalizeReviewCount("12.9")).toBe(12);
    expect(normalizeReviewCount(-4)).toBe(0);
    expect(normalizeReviewCount(null, 7)).toBe(7);
  });

  test("normalizes aliases and returns weighted fields", () => {
    const normalized = normalizeRatingResponse({
      rating: 4.9,
      totalReviews: "14",
    });

    expect(normalized.rawRating).toBe(4.9);
    expect(normalized.reviewCount).toBe(14);
    expect(normalized.ratingCount).toBe(14);
    expect(normalized.totalReviews).toBe(14);
    expect(normalized.rating).toBe(normalized.weightedRating);
    expect(normalized.rating).toBeLessThan(4.9);
  });
});

