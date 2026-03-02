describe('parcel_config', () => {
  const originalEnv = { ...process.env };

  const loadConfig = () => {
    jest.resetModules();
    // eslint-disable-next-line global-require
    return require('../config/parcel_config');
  };

  const restoreEnv = () => {
    for (const key of Object.keys(process.env)) {
      if (!(key in originalEnv)) {
        delete process.env[key];
      }
    }

    for (const [key, value] of Object.entries(originalEnv)) {
      process.env[key] = value;
    }
  };

  afterEach(() => {
    restoreEnv();
    jest.resetModules();
  });

  it('reads MAX_DECLARED_VALUE when parcel-specific key is not provided', () => {
    delete process.env.PARCEL_MAX_DECLARED_VALUE_GHS;
    process.env.MAX_DECLARED_VALUE = '750';

    const config = loadConfig();
    expect(config.maxDeclaredValueGhs).toBe(750);
  });

  it('prioritizes PARCEL_MAX_DECLARED_VALUE_GHS over MAX_DECLARED_VALUE', () => {
    process.env.PARCEL_MAX_DECLARED_VALUE_GHS = '650';
    process.env.MAX_DECLARED_VALUE = '900';

    const config = loadConfig();
    expect(config.maxDeclaredValueGhs).toBe(650);
  });
});
