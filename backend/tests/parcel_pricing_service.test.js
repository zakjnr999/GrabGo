const {
  calculateParcelQuote,
  calculateReturnFinancials,
} = require('../services/parcel_pricing_service');

describe('parcel_pricing_service', () => {
  const pickup = { latitude: 5.6037, longitude: -0.187 };
  const dropoff = { latitude: 5.65, longitude: -0.16 };

  it('returns quote with return-to-sender policy and rider earnings', () => {
    const result = calculateParcelQuote({
      pickup,
      dropoff,
      sizeTier: 'medium',
      weightKg: 3,
    });

    expect(result.quote.total).toBeGreaterThan(0);
    expect(result.returnPolicy.returnTripFeeEstimate).toBeGreaterThanOrEqual(0);
    expect(result.riderEarnings.originalTripEarning).toBeGreaterThan(0);
    expect(result.riderEarnings.totalPotentialEarning).toBeGreaterThanOrEqual(
      result.riderEarnings.originalTripEarning
    );
  });

  it('calculates explicit return-trip financials', () => {
    const returnFinancials = calculateReturnFinancials({ distanceKm: 4.5 });

    expect(returnFinancials.returnTripFee).toBeGreaterThan(0);
    expect(returnFinancials.returnTripEarning).toBeGreaterThan(0);
  });
});
