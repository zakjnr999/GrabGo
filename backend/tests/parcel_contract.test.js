const {
  PARCEL_API_PAYMENT_METHODS,
  PARCEL_PAYMENT_INPUT_VALUES,
  normalizeParcelPaymentMethod,
} = require('../contracts/parcel_contract');

describe('parcel_contract', () => {
  it('exposes API payment methods for frontend contract', () => {
    expect(PARCEL_API_PAYMENT_METHODS).toEqual(['card', 'paystack']);
    expect(PARCEL_PAYMENT_INPUT_VALUES).toEqual(['card', 'paystack', 'online']);
  });

  it('maps paystack and online inputs to storage-compatible online method', () => {
    expect(normalizeParcelPaymentMethod('paystack')).toEqual({
      apiMethod: 'paystack',
      storageMethod: 'online',
      provider: 'paystack',
    });

    expect(normalizeParcelPaymentMethod('online')).toEqual({
      apiMethod: 'paystack',
      storageMethod: 'online',
      provider: 'paystack',
    });
  });

  it('maps card input to card storage method', () => {
    expect(normalizeParcelPaymentMethod('card')).toEqual({
      apiMethod: 'card',
      storageMethod: 'card',
      provider: null,
    });
  });

  it('returns null for unsupported payment methods', () => {
    expect(normalizeParcelPaymentMethod('cash')).toBeNull();
  });
});
