const { defaultPolicyObject, checksum } = require('../services/fraud/fraud_policy_service');

describe('fraud_policy_service', () => {
  it('produces stable checksum for default policy', () => {
    const policyA = defaultPolicyObject();
    const policyB = defaultPolicyObject();

    expect(checksum(policyA)).toBe(checksum(policyB));
  });

  it('checksum changes when policy content changes', () => {
    const base = defaultPolicyObject();
    const changed = {
      ...base,
      thresholds: {
        ...base.thresholds,
        blockMin: Number(base.thresholds.blockMin) + 1,
      },
    };

    expect(checksum(base)).not.toBe(checksum(changed));
  });
});
