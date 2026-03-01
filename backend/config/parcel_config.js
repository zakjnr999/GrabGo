const parseFloatEnv = (name, fallback, { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const rawValue = process.env[name];
  if (rawValue === undefined || rawValue === null || rawValue === '') {
    return fallback;
  }

  const parsed = Number.parseFloat(String(rawValue));
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return fallback;
  }
  return parsed;
};

const parseIntEnv = (name, fallback, { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER } = {}) => {
  const rawValue = process.env[name];
  if (rawValue === undefined || rawValue === null || rawValue === '') {
    return fallback;
  }

  const parsed = Number.parseInt(String(rawValue), 10);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    return fallback;
  }
  return parsed;
};

const parseFlag = (name, fallback) => {
  const rawValue = process.env[name];
  if (rawValue === undefined || rawValue === null || rawValue === '') {
    return fallback;
  }

  const normalized = String(rawValue).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
};

module.exports = {
  maxDeclaredValueGhs: parseFloatEnv('PARCEL_MAX_DECLARED_VALUE_GHS', 500, {
    min: 1,
    max: 100000,
  }),
  liabilityCapGhs: parseFloatEnv('PARCEL_LIABILITY_CAP_GHS', 500, {
    min: 1,
    max: 100000,
  }),
  liabilityFormula: process.env.PARCEL_LIABILITY_FORMULA || 'min(declared_value, 500 GHS)',
  termsVersion: process.env.PARCEL_TERMS_VERSION || 'parcel-v1',
  scheduleToleranceMinutes: parseIntEnv('PARCEL_SCHEDULE_TOLERANCE_MINUTES', 15, {
    min: 0,
    max: 180,
  }),
  minScheduleLeadMinutes: parseIntEnv('PARCEL_MIN_SCHEDULE_LEAD_MINUTES', 30, {
    min: 0,
    max: 1440,
  }),
  maxWeightKg: parseFloatEnv('PARCEL_MAX_WEIGHT_KG', 30, {
    min: 0.1,
    max: 200,
  }),
  maxDimensionCm: parseFloatEnv('PARCEL_MAX_DIMENSION_CM', 200, {
    min: 1,
    max: 1000,
  }),
  noInsuranceEnabled: true,

  pricing: {
    baseFeeGhs: parseFloatEnv('PARCEL_BASE_FEE_GHS', 8, { min: 0, max: 100000 }),
    feePerKmGhs: parseFloatEnv('PARCEL_FEE_PER_KM_GHS', 2.2, { min: 0, max: 100000 }),
    feePerMinuteGhs: parseFloatEnv('PARCEL_FEE_PER_MIN_GHS', 0.15, { min: 0, max: 1000 }),
    serviceFeeRate: parseFloatEnv('PARCEL_SERVICE_FEE_RATE', 0.03, { min: 0, max: 1 }),
    taxRate: parseFloatEnv('PARCEL_TAX_RATE', 0, { min: 0, max: 1 }),
    weightFeePerKgGhs: parseFloatEnv('PARCEL_WEIGHT_FEE_PER_KG_GHS', 0.25, {
      min: 0,
      max: 1000,
    }),
    sizeTierSurchargeGhs: {
      small: parseFloatEnv('PARCEL_SIZE_SURCHARGE_SMALL_GHS', 0, { min: 0, max: 100000 }),
      medium: parseFloatEnv('PARCEL_SIZE_SURCHARGE_MEDIUM_GHS', 2, { min: 0, max: 100000 }),
      large: parseFloatEnv('PARCEL_SIZE_SURCHARGE_LARGE_GHS', 5, { min: 0, max: 100000 }),
      xlarge: parseFloatEnv('PARCEL_SIZE_SURCHARGE_XLARGE_GHS', 8, { min: 0, max: 100000 }),
    },
  },

  returnToSender: {
    customerChargeEnabled: parseFlag('PARCEL_RETURN_FEE_ENABLED', false),
    baseFeeGhs: parseFloatEnv('PARCEL_RETURN_BASE_FEE_GHS', 5, {
      min: 0,
      max: 100000,
    }),
    feePerKmGhs: parseFloatEnv('PARCEL_RETURN_FEE_PER_KM_GHS', 1.7, {
      min: 0,
      max: 100000,
    }),
    feePerMinuteGhs: parseFloatEnv('PARCEL_RETURN_FEE_PER_MIN_GHS', 0.1, {
      min: 0,
      max: 1000,
    }),
  },

  riderEarnings: {
    baseFeeGhs: parseFloatEnv('PARCEL_RIDER_BASE_FEE_GHS', 5, { min: 0, max: 100000 }),
    feePerKmGhs: parseFloatEnv('PARCEL_RIDER_FEE_PER_KM_GHS', 2, { min: 0, max: 100000 }),
    platformCommissionRate: parseFloatEnv('PARCEL_PLATFORM_COMMISSION_RATE', 0.15, {
      min: 0,
      max: 1,
    }),
  },
};
