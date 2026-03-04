const {
  buildFraudContext,
  computeContextHash,
  validateContext,
} = require('../services/fraud/fraud_context');
const { ACTION_TYPES } = require('../services/fraud/constants');

describe('fraud_context', () => {
  it('computes deterministic context hash for equivalent objects', () => {
    const first = {
      actionType: ACTION_TYPES.ORDER_CREATE,
      contextVersion: 1,
      context: {
        b: 2,
        a: 1,
        nested: { y: true, x: 'value' },
      },
    };

    const second = {
      actionType: ACTION_TYPES.ORDER_CREATE,
      contextVersion: 1,
      context: {
        nested: { x: 'value', y: true },
        a: 1,
        b: 2,
      },
    };

    expect(computeContextHash(first)).toBe(computeContextHash(second));
  });

  it('builds context with required envelope fields', () => {
    const context = buildFraudContext({
      actionType: ACTION_TYPES.AUTH_LOGIN,
      actorType: 'customer',
      actorId: 'user_1',
      requestId: 'req-123',
      context: {
        principal: 'user@example.com',
        ipHash: 'ip_hash',
      },
    });

    expect(context.contextVersion).toBe(1);
    expect(context.actionType).toBe(ACTION_TYPES.AUTH_LOGIN);
    expect(context.actorType).toBe('customer');
    expect(context.actorId).toBe('user_1');
    expect(context.contextHash).toBeTruthy();
  });

  it('validates missing required fields according to action rules', () => {
    const context = buildFraudContext({
      actionType: ACTION_TYPES.ORDER_CREATE,
      actorType: 'customer',
      actorId: 'user_1',
      context: {
        paymentMethod: 'card',
        amount: 42,
      },
    });

    const validation = validateContext({
      actionType: ACTION_TYPES.ORDER_CREATE,
      context,
    });

    expect(validation.valid).toBe(false);
    expect(validation.rule.missingRequired).toBe('fail_closed');
    expect(validation.missing).toContain('orderId');
    expect(validation.missing).toContain('ipHash');
  });
});
