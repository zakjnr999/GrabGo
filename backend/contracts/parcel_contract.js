const PARCEL_SIZE_TIERS = Object.freeze(['small', 'medium', 'large', 'xlarge']);
const PARCEL_SCHEDULE_TYPES = Object.freeze(['on_demand', 'scheduled']);

// API-facing payment values.
const PARCEL_API_PAYMENT_METHODS = Object.freeze(['card', 'paystack']);
// Legacy input accepted for backward compatibility.
const PARCEL_PAYMENT_INPUT_VALUES = Object.freeze(['card', 'paystack', 'online']);
// Storage values constrained by Prisma PaymentMethod enum.
const PARCEL_STORAGE_PAYMENT_METHODS = Object.freeze(['card', 'online']);

const PARCEL_PAYMENT_METHOD_ALIASES = Object.freeze({
  online: 'paystack',
});

const normalizePaymentMethodValue = (value) => String(value || '').trim().toLowerCase();

const normalizeParcelPaymentMethod = (value, { fallback = 'card' } = {}) => {
  const normalizedInput = normalizePaymentMethodValue(value) || normalizePaymentMethodValue(fallback);

  if (normalizedInput === 'card') {
    return {
      apiMethod: 'card',
      storageMethod: 'card',
      provider: null,
    };
  }

  if (normalizedInput === 'paystack' || normalizedInput === 'online') {
    return {
      apiMethod: 'paystack',
      storageMethod: 'online',
      provider: 'paystack',
    };
  }

  return null;
};

module.exports = {
  PARCEL_SIZE_TIERS,
  PARCEL_SCHEDULE_TYPES,
  PARCEL_API_PAYMENT_METHODS,
  PARCEL_PAYMENT_INPUT_VALUES,
  PARCEL_STORAGE_PAYMENT_METHODS,
  PARCEL_PAYMENT_METHOD_ALIASES,
  normalizeParcelPaymentMethod,
};
