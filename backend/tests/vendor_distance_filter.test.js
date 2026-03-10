const { validateLocationParams } = require('../utils/vendor_distance_filter');

describe('vendor_distance_filter', () => {
  test('accepts zero-value coordinates as valid input', () => {
    expect(validateLocationParams('0', '0', '10')).toEqual({
      userLatitude: 0,
      userLongitude: 0,
      maxDistanceKm: 10,
    });
  });

  test('returns null when either coordinate is missing', () => {
    expect(validateLocationParams(null, '0.2', '10')).toBeNull();
    expect(validateLocationParams('5.6', '', '10')).toBeNull();
  });
});
