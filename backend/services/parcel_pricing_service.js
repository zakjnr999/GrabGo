const parcelConfig = require('../config/parcel_config');
const { calculateDistance, estimateDeliveryTime } = require('../utils/distance');
const {
  calculateParcelLegEarnings,
  calculateParcelRoundTripEarnings,
} = require('../utils/riderEarningsCalculator');

const roundCurrency = (value) => Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;

const toNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const calculateLegDistanceAndDuration = ({ pickup, dropoff }) => {
  const distanceKm = calculateDistance(
    pickup.latitude,
    pickup.longitude,
    dropoff.latitude,
    dropoff.longitude
  );
  const roundedDistanceKm = roundCurrency(distanceKm);
  const estimatedMinutes = estimateDeliveryTime(Math.max(distanceKm, 0));

  return {
    distanceKm: roundedDistanceKm,
    estimatedMinutes,
  };
};

const resolveSizeTierSurcharge = (sizeTier) => {
  const key = String(sizeTier || '').trim().toLowerCase();
  return toNumber(parcelConfig.pricing.sizeTierSurchargeGhs[key], 0);
};

const calculateOriginalTripFee = ({ distanceKm, estimatedMinutes, sizeTier, weightKg }) => {
  const baseFee = toNumber(parcelConfig.pricing.baseFeeGhs, 0);
  const distanceFee = distanceKm * toNumber(parcelConfig.pricing.feePerKmGhs, 0);
  const timeFee = estimatedMinutes * toNumber(parcelConfig.pricing.feePerMinuteGhs, 0);
  const sizeFee = resolveSizeTierSurcharge(sizeTier);
  const weightFee = Math.max(0, weightKg) * toNumber(parcelConfig.pricing.weightFeePerKgGhs, 0);

  const subtotal = baseFee + distanceFee + timeFee + sizeFee + weightFee;

  return {
    baseFee: roundCurrency(baseFee),
    distanceFee: roundCurrency(distanceFee),
    timeFee: roundCurrency(timeFee),
    sizeFee: roundCurrency(sizeFee),
    weightFee: roundCurrency(weightFee),
    subtotal: roundCurrency(subtotal),
  };
};

const calculateReturnTripFee = ({ distanceKm, estimatedMinutes }) => {
  const baseFee = toNumber(parcelConfig.returnToSender.baseFeeGhs, 0);
  const distanceFee = distanceKm * toNumber(parcelConfig.returnToSender.feePerKmGhs, 0);
  const timeFee = estimatedMinutes * toNumber(parcelConfig.returnToSender.feePerMinuteGhs, 0);
  const total = baseFee + distanceFee + timeFee;
  return {
    baseFee: roundCurrency(baseFee),
    distanceFee: roundCurrency(distanceFee),
    timeFee: roundCurrency(timeFee),
    total: roundCurrency(total),
  };
};

const calculateParcelQuote = ({ pickup, dropoff, sizeTier, weightKg }) => {
  const { distanceKm, estimatedMinutes } = calculateLegDistanceAndDuration({ pickup, dropoff });
  const originalTrip = calculateOriginalTripFee({
    distanceKm,
    estimatedMinutes,
    sizeTier,
    weightKg,
  });

  const serviceFee = roundCurrency(originalTrip.subtotal * toNumber(parcelConfig.pricing.serviceFeeRate, 0));
  const taxableAmount = originalTrip.subtotal + serviceFee;
  const tax = roundCurrency(taxableAmount * toNumber(parcelConfig.pricing.taxRate, 0));
  const total = roundCurrency(originalTrip.subtotal + serviceFee + tax);

  const returnTrip = calculateReturnTripFee({ distanceKm, estimatedMinutes });
  const riderEarnings = calculateParcelRoundTripEarnings(
    {
      originalDistanceKm: distanceKm,
      returnDistanceKm: distanceKm,
    },
    {
      baseFee: toNumber(parcelConfig.riderEarnings.baseFeeGhs, 0),
      ratePerKm: toNumber(parcelConfig.riderEarnings.feePerKmGhs, 0),
      platformCommissionRate: toNumber(parcelConfig.riderEarnings.platformCommissionRate, 0),
    }
  );

  return {
    quote: {
      distanceKm,
      estimatedMinutes,
      subtotal: originalTrip.subtotal,
      serviceFee,
      tax,
      total,
      currency: 'GHS',
      breakdown: originalTrip,
    },
    returnPolicy: {
      customerChargeEnabled: parcelConfig.returnToSender.customerChargeEnabled,
      returnTripFeeEstimate: parcelConfig.returnToSender.customerChargeEnabled ? returnTrip.total : 0,
      returnTripBreakdown: returnTrip,
    },
    riderEarnings: {
      originalTripEarning: riderEarnings.originalTripEarning,
      returnTripEarning: riderEarnings.returnTripEarning,
      totalPotentialEarning: riderEarnings.totalRiderEarnings,
      breakdown: {
        originalTrip: riderEarnings.breakdown.originalTrip,
        returnTrip: riderEarnings.breakdown.returnTrip,
      },
    },
  };
};

const calculateReturnFinancials = ({ distanceKm }) => {
  const durationMinutes = estimateDeliveryTime(Math.max(distanceKm, 0));
  const returnTripFee = calculateReturnTripFee({ distanceKm, estimatedMinutes: durationMinutes });
  const returnRiderEarning = calculateParcelLegEarnings(distanceKm, {
    baseFee: toNumber(parcelConfig.riderEarnings.baseFeeGhs, 0),
    ratePerKm: toNumber(parcelConfig.riderEarnings.feePerKmGhs, 0),
    platformCommissionRate: toNumber(parcelConfig.riderEarnings.platformCommissionRate, 0),
  });

  return {
    returnTripFee: returnTripFee.total,
    returnTripFeeBreakdown: returnTripFee,
    returnTripEarning: returnRiderEarning.riderEarnings,
    returnTripEarningBreakdown: returnRiderEarning,
  };
};

module.exports = {
  calculateParcelQuote,
  calculateReturnFinancials,
};
