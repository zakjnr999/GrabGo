/**
 * Promo code smoke test (Prisma)
 *
 * Usage:
 *   node backend/scripts/test_promo_codes.js
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const prisma = require('../config/prisma');
const {
  validatePromoCode,
  applyPromoCode,
  createPromoCode,
} = require('../services/promo_service');

const TEST_CODES = ['FAVE10', 'REORDER10', 'TEST20', 'FIRSTORDER'];

const seedPromoCodes = async () => {
  await prisma.promoCode.deleteMany({
    where: { code: { in: TEST_CODES } },
  });

  const promoCodes = [
    {
      code: 'FAVE10',
      type: 'percentage',
      value: 10,
      description: '10% off for favorites reminder',
      minOrderAmount: 0,
      maxUsesPerUser: 3,
    },
    {
      code: 'REORDER10',
      type: 'percentage',
      value: 10,
      description: '10% off for reorder suggestions',
      minOrderAmount: 0,
      maxUsesPerUser: 3,
    },
    {
      code: 'TEST20',
      type: 'percentage',
      value: 20,
      description: '20% off test code',
      minOrderAmount: 20,
      maxDiscountAmount: 50,
    },
    {
      code: 'FIRSTORDER',
      type: 'fixed',
      value: 15,
      description: 'GHS 15 off first order',
      firstOrderOnly: true,
      maxUsesPerUser: 1,
    },
  ];

  for (const code of promoCodes) {
    await createPromoCode(code);
  }

  return promoCodes.length;
};

const run = async () => {
  console.log('Promo smoke test');
  console.log('='.repeat(40));

  try {
    console.log('\n1) Seeding test promo codes...');
    const createdCount = await seedPromoCodes();
    console.log(`OK: created ${createdCount} promo codes`);

    console.log('\n2) Selecting customer user...');
    const user = await prisma.user.findFirst({
      where: {
        role: 'customer',
        isActive: true,
      },
      select: {
        id: true,
        email: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    if (!user) {
      console.error('FAIL: no active customer user found');
      process.exitCode = 1;
      return;
    }
    console.log(`OK: using ${user.email} (${user.id})`);

    console.log('\n3) Validation checks...');
    const validResult = await validatePromoCode('FAVE10', user.id, 50, 'food');
    console.log(
      validResult.valid
        ? `OK: FAVE10 valid, discount GHS ${validResult.discount}`
        : `FAIL: FAVE10 invalid -> ${validResult.error}`
    );

    const minOrderResult = await validatePromoCode('TEST20', user.id, 15, 'food');
    console.log(
      !minOrderResult.valid
        ? `OK: TEST20 rejected below minimum -> ${minOrderResult.error}`
        : 'FAIL: TEST20 should be rejected for low order amount'
    );

    const validMinResult = await validatePromoCode('TEST20', user.id, 100, 'food');
    console.log(
      validMinResult.valid
        ? `OK: TEST20 valid at high subtotal, discount GHS ${validMinResult.discount}`
        : `FAIL: TEST20 invalid at high subtotal -> ${validMinResult.error}`
    );

    const invalidResult = await validatePromoCode('INVALID', user.id, 50, 'food');
    console.log(
      !invalidResult.valid
        ? `OK: INVALID rejected -> ${invalidResult.error}`
        : 'FAIL: INVALID should be rejected'
    );

    console.log('\n4) Apply check (usage counter)...');
    const fakeOrderId = `promo-smoke-${Date.now()}`;
    const applyResult = await applyPromoCode('FAVE10', user.id, fakeOrderId, 5.0);
    console.log(
      applyResult.success
        ? 'OK: applyPromoCode returned success'
        : `FAIL: applyPromoCode failed -> ${applyResult.error}`
    );

    const updatedPromo = await prisma.promoCode.findUnique({
      where: { code: 'FAVE10' },
      select: { currentUses: true },
    });

    const currentUses = Number(updatedPromo?.currentUses || 0);
    console.log(`FAVE10 currentUses=${currentUses}`);
    if (currentUses <= 0) {
      console.error('FAIL: expected currentUses to increment');
      process.exitCode = 1;
      return;
    }

    console.log('\nPromo smoke test completed');
  } catch (error) {
    console.error('\nFAIL:', error.message);
    console.error(error.stack);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect().catch(() => null);
  }
};

run();
