const LEVELS = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

const currentLevel = (() => {
  const configuredLevel = String(
    process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug')
  ).toLowerCase();

  return LEVELS[configuredLevel] ? configuredLevel : 'info';
})();

const REDACTED_KEYS = [
  'authorization',
  'token',
  'password',
  'secret',
  'cookie',
  'apiKey',
  'api_key',
  'jwt',
  'refreshToken',
];

const shouldLog = (level) => LEVELS[level] >= LEVELS[currentLevel];

const isPlainObject = (value) =>
  value !== null && typeof value === 'object' && !Array.isArray(value);

const sanitizeValue = (value, depth = 0) => {
  if (depth > 4) {
    return '[Truncated]';
  }

  if (value instanceof Error) {
    return {
      name: value.name,
      message: value.message,
      ...(process.env.NODE_ENV !== 'production' && value.stack
        ? { stack: value.stack }
        : {}),
    };
  }

  if (Array.isArray(value)) {
    return value.slice(0, 25).map((item) => sanitizeValue(item, depth + 1));
  }

  if (isPlainObject(value)) {
    return Object.entries(value).reduce((acc, [key, nestedValue]) => {
      const shouldRedact = REDACTED_KEYS.some((candidate) =>
        key.toLowerCase().includes(candidate.toLowerCase())
      );
      acc[key] = shouldRedact ? '[REDACTED]' : sanitizeValue(nestedValue, depth + 1);
      return acc;
    }, {});
  }

  if (typeof value === 'string') {
    return value.length > 1000 ? `${value.slice(0, 1000)}...[truncated]` : value;
  }

  return value;
};

const writeLog = (level, message, meta) => {
  if (!shouldLog(level)) {
    return;
  }

  const payload = {
    time: new Date().toISOString(),
    level,
    message,
  };

  if (meta !== undefined) {
    payload.meta = sanitizeValue(meta);
  }

  const line = `${JSON.stringify(payload)}\n`;
  if (level === 'error') {
    process.stderr.write(line);
    return;
  }
  process.stdout.write(line);
};

const normalizeScopedArgs = (scope, args) => {
  const [firstArg, ...restArgs] = args;

  if (typeof firstArg === 'string') {
    if (restArgs.length === 0) {
      return {
        message: firstArg,
        meta: { scope },
      };
    }

    return {
      message: firstArg,
      meta: {
        scope,
        args: restArgs.length === 1 ? restArgs[0] : restArgs,
      },
    };
  }

  return {
    message: `${scope}_log`,
    meta: {
      scope,
      args,
    },
  };
};

const createScopedLogger = (scope) => ({
  log: (...args) => {
    const { message, meta } = normalizeScopedArgs(scope, args);
    writeLog('debug', message, meta);
  },
  info: (...args) => {
    const { message, meta } = normalizeScopedArgs(scope, args);
    writeLog('info', message, meta);
  },
  warn: (...args) => {
    const { message, meta } = normalizeScopedArgs(scope, args);
    writeLog('warn', message, meta);
  },
  error: (...args) => {
    const { message, meta } = normalizeScopedArgs(scope, args);
    writeLog('error', message, meta);
  },
});

module.exports = {
  debug: (message, meta) => writeLog('debug', message, meta),
  info: (message, meta) => writeLog('info', message, meta),
  warn: (message, meta) => writeLog('warn', message, meta),
  error: (message, meta) => writeLog('error', message, meta),
  createScopedLogger,
};
