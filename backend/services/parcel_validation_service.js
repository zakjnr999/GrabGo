const parcelConfig = require('../config/parcel_config');

class ParcelValidationError extends Error {
  constructor(message, status = 400, code = 'PARCEL_VALIDATION_ERROR', details = []) {
    super(message);
    this.name = 'ParcelValidationError';
    this.status = status;
    this.code = code;
    this.details = Array.isArray(details) ? details : [];
  }
}

const VALID_SIZE_TIERS = new Set(['small', 'medium', 'large', 'xlarge']);
const VALID_SCHEDULE_TYPES = new Set(['on_demand', 'scheduled']);
const VALID_PAYMENT_METHODS = new Set(['card', 'online']);

const toNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const normalizeString = (value) => String(value || '').trim();

const normalizeBoolean = (value) => value === true || String(value).trim().toLowerCase() === 'true';

const normalizePhone = (value) => {
  const raw = normalizeString(value);
  if (!raw) return '';
  return raw.replace(/\s+/g, '');
};

const normalizeScheduleType = (value) => {
  const normalized = normalizeString(value).toLowerCase();
  if (normalized === 'scheduled') return 'scheduled';
  if (normalized === 'on_demand') return 'on_demand';
  if (normalized === 'immediate') return 'on_demand';
  if (normalized === 'now') return 'on_demand';
  return 'on_demand';
};

const parseScheduledPickupAt = (value) => {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const normalizeStop = (payload, key) => {
  const stop = payload?.[key] || {};
  const fallbackPrefix = key === 'pickup' ? 'pickup' : 'dropoff';

  const latitude = toNumber(stop.latitude ?? stop.lat ?? payload?.[`${fallbackPrefix}Latitude`]);
  const longitude = toNumber(stop.longitude ?? stop.lng ?? payload?.[`${fallbackPrefix}Longitude`]);

  return {
    addressLine1: normalizeString(stop.addressLine1 ?? stop.address ?? payload?.[`${fallbackPrefix}AddressLine1`]),
    addressLine2: normalizeString(stop.addressLine2 ?? payload?.[`${fallbackPrefix}AddressLine2`]),
    city: normalizeString(stop.city ?? payload?.[`${fallbackPrefix}City`]),
    state: normalizeString(stop.state ?? payload?.[`${fallbackPrefix}State`]),
    postalCode: normalizeString(stop.postalCode ?? stop.zipCode ?? payload?.[`${fallbackPrefix}PostalCode`]),
    latitude,
    longitude,
    contactName: normalizeString(stop.contactName ?? payload?.[`${fallbackPrefix}ContactName`]),
    contactPhone: normalizePhone(stop.contactPhone ?? payload?.[`${fallbackPrefix}ContactPhone`]),
    notes: normalizeString(stop.notes),
  };
};

const assertCoordinatePair = (stop, fieldPath, errors) => {
  if (!Number.isFinite(stop.latitude) || stop.latitude < -90 || stop.latitude > 90) {
    errors.push({ field: `${fieldPath}.latitude`, message: 'Latitude must be between -90 and 90' });
  }
  if (!Number.isFinite(stop.longitude) || stop.longitude < -180 || stop.longitude > 180) {
    errors.push({ field: `${fieldPath}.longitude`, message: 'Longitude must be between -180 and 180' });
  }
};

const assertRequiredAddressFields = (stop, fieldPath, errors) => {
  if (!stop.addressLine1) {
    errors.push({ field: `${fieldPath}.addressLine1`, message: 'Address line 1 is required' });
  }
  if (!stop.city) {
    errors.push({ field: `${fieldPath}.city`, message: 'City is required' });
  }
};

const assertRequiredContactFields = (stop, fieldPath, errors) => {
  if (!stop.contactName) {
    errors.push({ field: `${fieldPath}.contactName`, message: 'Contact name is required' });
  }
  if (!stop.contactPhone) {
    errors.push({ field: `${fieldPath}.contactPhone`, message: 'Contact phone is required' });
  }
};

const normalizeParcelInput = (payload = {}, options = {}) => {
  const {
    requireTermsAcceptance = false,
    allowScheduled = true,
    requireRecipient = true,
    requireProhibitedItemsAcceptance = true,
  } = options;

  const errors = [];

  const pickup = normalizeStop(payload, 'pickup');
  const dropoff = normalizeStop(payload, 'dropoff');

  assertRequiredAddressFields(pickup, 'pickup', errors);
  assertRequiredAddressFields(dropoff, 'dropoff', errors);
  assertCoordinatePair(pickup, 'pickup', errors);
  assertCoordinatePair(dropoff, 'dropoff', errors);

  assertRequiredContactFields(pickup, 'pickup', errors);
  if (requireRecipient) {
    assertRequiredContactFields(dropoff, 'dropoff', errors);
  }

  const declaredValueGhs = toNumber(payload.declaredValueGhs ?? payload.declaredValue);
  if (!Number.isFinite(declaredValueGhs) || declaredValueGhs <= 0) {
    errors.push({ field: 'declaredValueGhs', message: 'Declared value must be greater than 0' });
  } else if (declaredValueGhs > parcelConfig.maxDeclaredValueGhs) {
    errors.push({
      field: 'declaredValueGhs',
      message: `Declared value cannot exceed GHS ${parcelConfig.maxDeclaredValueGhs}`,
    });
  }

  const weightKg = toNumber(payload.weightKg);
  if (!Number.isFinite(weightKg) || weightKg <= 0) {
    errors.push({ field: 'weightKg', message: 'Weight is required and must be greater than 0' });
  } else if (weightKg > parcelConfig.maxWeightKg) {
    errors.push({
      field: 'weightKg',
      message: `Weight cannot exceed ${parcelConfig.maxWeightKg}kg`,
    });
  }

  const lengthCm = toNumber(payload.lengthCm);
  const widthCm = toNumber(payload.widthCm);
  const heightCm = toNumber(payload.heightCm);
  const sizeDimensions = [
    ['lengthCm', lengthCm],
    ['widthCm', widthCm],
    ['heightCm', heightCm],
  ];
  sizeDimensions.forEach(([field, value]) => {
    if (value !== null && value > parcelConfig.maxDimensionCm) {
      errors.push({
        field,
        message: `Dimension cannot exceed ${parcelConfig.maxDimensionCm}cm`,
      });
    }
  });

  const sizeTier = normalizeString(payload.sizeTier).toLowerCase() || 'medium';
  if (!VALID_SIZE_TIERS.has(sizeTier)) {
    errors.push({
      field: 'sizeTier',
      message: `Size tier must be one of: ${Array.from(VALID_SIZE_TIERS).join(', ')}`,
    });
  }

  const containsHazardous = normalizeBoolean(payload.containsHazardous);
  if (containsHazardous) {
    errors.push({
      field: 'containsHazardous',
      message: 'Hazardous parcels are not supported',
    });
  }

  if (requireProhibitedItemsAcceptance && !normalizeBoolean(payload.prohibitedItemsAccepted)) {
    errors.push({
      field: 'prohibitedItemsAccepted',
      message: 'You must accept prohibited-items confirmation',
    });
  }

  const paymentMethod = normalizeString(payload.paymentMethod).toLowerCase() || 'card';
  if (!VALID_PAYMENT_METHODS.has(paymentMethod)) {
    errors.push({
      field: 'paymentMethod',
      message: `Payment method must be one of: ${Array.from(VALID_PAYMENT_METHODS).join(', ')}`,
    });
  }

  const scheduleType = normalizeScheduleType(payload.scheduleType ?? payload.deliveryTimeType);
  if (!VALID_SCHEDULE_TYPES.has(scheduleType)) {
    errors.push({
      field: 'scheduleType',
      message: `Schedule type must be one of: ${Array.from(VALID_SCHEDULE_TYPES).join(', ')}`,
    });
  }

  if (!allowScheduled && scheduleType === 'scheduled') {
    errors.push({
      field: 'scheduleType',
      message: 'Scheduled pickup is currently disabled',
    });
  }

  let scheduledPickupAt = null;
  if (scheduleType === 'scheduled') {
    scheduledPickupAt = parseScheduledPickupAt(payload.scheduledPickupAt ?? payload.scheduledForAt);
    if (!scheduledPickupAt) {
      errors.push({
        field: 'scheduledPickupAt',
        message: 'Scheduled pickup time is required for scheduled parcels',
      });
    } else {
      const minLeadMs = parcelConfig.minScheduleLeadMinutes * 60 * 1000;
      if (scheduledPickupAt.getTime() < Date.now() + minLeadMs) {
        errors.push({
          field: 'scheduledPickupAt',
          message: `Scheduled pickup must be at least ${parcelConfig.minScheduleLeadMinutes} minutes from now`,
        });
      }
    }
  }

  const termsVersion = normalizeString(payload.termsVersion || parcelConfig.termsVersion);
  if (requireTermsAcceptance && !normalizeBoolean(payload.acceptParcelTerms)) {
    errors.push({
      field: 'acceptParcelTerms',
      message: 'Parcel terms must be accepted before creating an order',
    });
  }

  if (requireTermsAcceptance && termsVersion !== parcelConfig.termsVersion) {
    errors.push({
      field: 'termsVersion',
      message: `Unsupported parcel terms version. Expected ${parcelConfig.termsVersion}`,
    });
  }

  if (errors.length > 0) {
    throw new ParcelValidationError('Parcel validation failed', 400, 'PARCEL_VALIDATION_ERROR', errors);
  }

  return {
    pickup,
    dropoff,
    packageCategory: normalizeString(payload.packageCategory || 'general'),
    packageDescription: normalizeString(payload.packageDescription),
    sizeTier,
    weightKg,
    lengthCm,
    widthCm,
    heightCm,
    declaredValueGhs,
    containsHazardous,
    containsLiquid: normalizeBoolean(payload.containsLiquid),
    isPerishable: normalizeBoolean(payload.isPerishable),
    isFragile: normalizeBoolean(payload.isFragile),
    prohibitedItemsAccepted: requireProhibitedItemsAcceptance
      ? true
      : normalizeBoolean(payload.prohibitedItemsAccepted),
    paymentMethod,
    scheduleType,
    scheduledPickupAt,
    notes: normalizeString(payload.notes),
    termsVersion,
  };
};

const buildScheduleWindow = ({ scheduleType, scheduledPickupAt }) => {
  if (scheduleType !== 'scheduled' || !scheduledPickupAt) {
    const now = new Date();
    return {
      scheduledPickupAt: null,
      pickupWindowStartAt: null,
      pickupWindowEndAt: null,
      dispatchReleaseAt: now,
      dispatchReleasedAt: now,
    };
  }

  const toleranceMs = parcelConfig.scheduleToleranceMinutes * 60 * 1000;
  const pickupWindowStartAt = new Date(scheduledPickupAt.getTime() - toleranceMs);
  const pickupWindowEndAt = new Date(scheduledPickupAt.getTime() + toleranceMs);

  return {
    scheduledPickupAt,
    pickupWindowStartAt,
    pickupWindowEndAt,
    dispatchReleaseAt: pickupWindowStartAt,
    dispatchReleasedAt: null,
  };
};

const buildLiabilitySnapshot = ({ declaredValueGhs }) => {
  const liabilityCapGhs = Math.min(parcelConfig.liabilityCapGhs, declaredValueGhs);
  return {
    liabilityCapGhs,
    liabilityFormula: parcelConfig.liabilityFormula,
  };
};

module.exports = {
  ParcelValidationError,
  VALID_SIZE_TIERS,
  normalizeParcelInput,
  buildScheduleWindow,
  buildLiabilitySnapshot,
};
