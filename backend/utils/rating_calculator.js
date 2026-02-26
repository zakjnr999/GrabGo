const DEFAULT_GLOBAL_MEAN = 4.2;
const DEFAULT_PRIOR_WEIGHT = 12;
const MIN_RATING = 0;
const MAX_RATING = 5;

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function toSafeNumber(value, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function roundToTenth(value) {
  return Math.round(value * 10) / 10;
}

function calculateWeightedRating(averageRating, ratingCount, options = {}) {
  const C = clamp(
    toSafeNumber(options.globalMean, DEFAULT_GLOBAL_MEAN),
    MIN_RATING,
    MAX_RATING
  );
  const m = Math.max(0, Math.floor(toSafeNumber(options.priorWeight, DEFAULT_PRIOR_WEIGHT)));
  const R = clamp(toSafeNumber(averageRating, 0), MIN_RATING, MAX_RATING);
  const v = Math.max(0, Math.floor(toSafeNumber(ratingCount, 0)));

  if (v <= 0) {
    return roundToTenth(C);
  }

  const weighted = (v / (v + m)) * R + (m / (v + m)) * C;
  return roundToTenth(clamp(weighted, MIN_RATING, MAX_RATING));
}

function normalizeReviewCount(value, fallback = 0) {
  return Math.max(0, Math.floor(toSafeNumber(value, fallback)));
}

function normalizeRatingResponse({
  rating,
  ratingCount,
  reviewCount,
  totalReviews,
  globalMean,
  priorWeight,
}) {
  const normalizedCount = normalizeReviewCount(
    reviewCount ?? totalReviews ?? ratingCount ?? 0
  );
  const rawRating = clamp(toSafeNumber(rating, 0), MIN_RATING, MAX_RATING);
  const weightedRating = calculateWeightedRating(rawRating, normalizedCount, {
    globalMean,
    priorWeight,
  });

  return {
    rawRating,
    rating: weightedRating,
    weightedRating,
    ratingCount: normalizedCount,
    reviewCount: normalizedCount,
    totalReviews: normalizedCount,
  };
}

module.exports = {
  calculateWeightedRating,
  normalizeReviewCount,
  normalizeRatingResponse,
  DEFAULT_GLOBAL_MEAN,
  DEFAULT_PRIOR_WEIGHT,
};
