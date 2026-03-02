const {
  ParcelValidationError,
  normalizeParcelInput,
  buildLiabilitySnapshot,
} = require('../services/parcel_validation_service');

const makeValidPayload = () => ({
  pickup: {
    addressLine1: '12 Sender Street',
    city: 'Accra',
    latitude: 5.6037,
    longitude: -0.187,
    contactName: 'Sender',
    contactPhone: '0200000000',
  },
  dropoff: {
    addressLine1: '8 Receiver Street',
    city: 'Accra',
    latitude: 5.65,
    longitude: -0.16,
    contactName: 'Receiver',
    contactPhone: '0240000000',
  },
  declaredValueGhs: 400,
  weightKg: 2,
  sizeTier: 'medium',
  prohibitedItemsAccepted: true,
  containsHazardous: false,
  acceptParcelTerms: true,
  termsVersion: 'parcel-v1',
  paymentMethod: 'card',
});

describe('parcel_validation_service', () => {
  it('rejects declared values above maximum cap', () => {
    expect(() => {
      normalizeParcelInput(
        {
          ...makeValidPayload(),
          declaredValueGhs: 501,
        },
        { requireTermsAcceptance: true }
      );
    }).toThrow(ParcelValidationError);
  });

  it('requires terms acceptance for order creation', () => {
    expect(() => {
      normalizeParcelInput(
        {
          ...makeValidPayload(),
          acceptParcelTerms: false,
        },
        { requireTermsAcceptance: true }
      );
    }).toThrow(ParcelValidationError);
  });

  it('allows quote validation without prohibited-items acceptance', () => {
    expect(() => {
      normalizeParcelInput(
        {
          ...makeValidPayload(),
          prohibitedItemsAccepted: false,
        },
        {
          requireTermsAcceptance: false,
          requireProhibitedItemsAcceptance: false,
        }
      );
    }).not.toThrow();
  });

  it('accepts paystack payment method and normalizes storage method', () => {
    const normalized = normalizeParcelInput({
      ...makeValidPayload(),
      paymentMethod: 'paystack',
    });

    expect(normalized.paymentMethod).toBe('online');
    expect(normalized.paymentMethodApi).toBe('paystack');
    expect(normalized.paymentProvider).toBe('paystack');
  });

  it('builds liability snapshot capped to configured limit', () => {
    const liability = buildLiabilitySnapshot({ declaredValueGhs: 450 });
    expect(liability.liabilityCapGhs).toBe(450);
    expect(liability.liabilityFormula).toContain('min');
  });
});
