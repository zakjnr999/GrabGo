const prisma = require('../config/prisma');

/**
 * Default vendor commission rate.
 * Can be overridden per-vendor via the `commissionRate` field on their model,
 * or globally via the `VENDOR_COMMISSION_RATE` env var.
 *
 * Set to 0 for launch (no commission). Raise to 0.10–0.15 after Month 3.
 */
const DEFAULT_VENDOR_COMMISSION_RATE = parseFloat(process.env.VENDOR_COMMISSION_RATE || '0');

/**
 * Resolve the vendor entity and commission rate for an order.
 *
 * @param {Object} params
 * @param {import('@prisma/client').PrismaClient} params.tx - Prisma transaction client
 * @param {Object} params.order - The order being settled
 * @returns {Object|null} { vendorId, vendorType, commissionRate, vendorName } or null
 */
const resolveVendor = async ({ tx, order }) => {
  if (order.restaurantId) {
    const vendor = await tx.restaurant.findUnique({
      where: { id: order.restaurantId },
      select: { id: true, restaurantName: true, commissionRate: true, isGrabGoExclusive: true },
    });
    if (!vendor) return null;
    return {
      vendorId: vendor.id,
      vendorType: 'restaurant',
      vendorName: vendor.restaurantName,
      commissionRate: vendor.commissionRate ?? DEFAULT_VENDOR_COMMISSION_RATE,
    };
  }

  if (order.groceryStoreId) {
    const vendor = await tx.groceryStore.findUnique({
      where: { id: order.groceryStoreId },
      select: { id: true, storeName: true, commissionRate: true, isGrabGoExclusive: true },
    });
    if (!vendor) return null;
    return {
      vendorId: vendor.id,
      vendorType: 'grocery',
      vendorName: vendor.storeName,
      commissionRate: vendor.commissionRate ?? DEFAULT_VENDOR_COMMISSION_RATE,
    };
  }

  if (order.pharmacyStoreId) {
    const vendor = await tx.pharmacyStore.findUnique({
      where: { id: order.pharmacyStoreId },
      select: { id: true, storeName: true, commissionRate: true, isGrabGoExclusive: true },
    });
    if (!vendor) return null;
    return {
      vendorId: vendor.id,
      vendorType: 'pharmacy',
      vendorName: vendor.storeName,
      commissionRate: vendor.commissionRate ?? DEFAULT_VENDOR_COMMISSION_RATE,
    };
  }

  if (order.grabMartStoreId) {
    const vendor = await tx.grabMartStore.findUnique({
      where: { id: order.grabMartStoreId },
      select: { id: true, storeName: true, commissionRate: true, isGrabGoExclusive: true },
    });
    if (!vendor) return null;
    return {
      vendorId: vendor.id,
      vendorType: 'grabmart',
      vendorName: vendor.storeName,
      commissionRate: vendor.commissionRate ?? DEFAULT_VENDOR_COMMISSION_RATE,
    };
  }

  return null;
};

/**
 * Calculate vendor commission for an order.
 *
 * @param {number} subtotal - The order food/item subtotal
 * @param {number} commissionRate - The vendor's commission rate (e.g., 0.15 for 15%)
 * @returns {Object} { vendorCommission, vendorPayout }
 */
const calculateVendorCommission = (subtotal, commissionRate) => {
  const rate = Math.max(0, Math.min(1, commissionRate)); // Clamp 0–100%
  const vendorCommission = parseFloat((subtotal * rate).toFixed(2));
  const vendorPayout = parseFloat((subtotal - vendorCommission).toFixed(2));
  return { vendorCommission, vendorPayout, vendorCommissionRate: rate };
};

/**
 * Settle vendor earnings inside a Prisma transaction.
 * Called from delivery_settlement_service alongside rider settlement.
 *
 * This function:
 * 1. Resolves the vendor and their commission rate
 * 2. Calculates commission and payout amounts
 * 3. Updates the Order with vendor financial fields
 * 4. Credits the vendor wallet (creates if needed)
 * 5. Records vendor transactions (sale + commission deduction)
 *
 * @param {Object} params
 * @param {import('@prisma/client').PrismaClient} params.tx - Prisma transaction client
 * @param {Object} params.order - The delivered order
 * @returns {Object} { vendorId, vendorType, vendorCommission, vendorPayout, settled }
 */
const settleVendorInTransaction = async ({ tx, order }) => {
  const subtotal = Number(order.subtotal) || 0;
  if (subtotal <= 0) {
    console.log(`[VendorSettlement] Skipping order=${order.id} — zero subtotal`);
    return { vendorId: null, vendorType: null, vendorCommission: 0, vendorPayout: 0, settled: false };
  }

  // 1. Resolve vendor
  const vendor = await resolveVendor({ tx, order });
  if (!vendor) {
    console.log(`[VendorSettlement] No vendor found for order=${order.id}`);
    return { vendorId: null, vendorType: null, vendorCommission: 0, vendorPayout: 0, settled: false };
  }

  // 2. Calculate commission
  const { vendorCommission, vendorPayout, vendorCommissionRate } = calculateVendorCommission(
    subtotal,
    vendor.commissionRate
  );

  // 3. Update Order with vendor financial breakdown
  await tx.order.update({
    where: { id: order.id },
    data: {
      vendorCommissionRate,
      vendorCommission,
      vendorPayout,
    },
  });

  // 4. Find or create vendor wallet
  let wallet = await tx.vendorWallet.findUnique({
    where: { vendorId: vendor.vendorId },
  });

  if (!wallet) {
    wallet = await tx.vendorWallet.create({
      data: {
        vendorId: vendor.vendorId,
        vendorType: vendor.vendorType,
      },
    });
  }

  // 5. Idempotency check — has this order already been settled for this vendor?
  const existingTx = await tx.vendorTransaction.findFirst({
    where: {
      referenceId: order.id,
      type: 'sale',
      vendorId: vendor.vendorId,
    },
  });

  if (existingTx) {
    console.log(`[VendorSettlement] Already settled order=${order.id} for vendor=${vendor.vendorId}, skipping`);
    return {
      vendorId: vendor.vendorId,
      vendorType: vendor.vendorType,
      vendorCommission,
      vendorPayout,
      settled: false,
    };
  }

  // 6. Record sale transaction (the full subtotal)
  await tx.vendorTransaction.create({
    data: {
      walletId: wallet.id,
      vendorId: vendor.vendorId,
      type: 'sale',
      amount: vendorPayout,
      description: `Sale from order ${order.orderNumber || order.id} (${subtotal} − ${vendorCommission} commission)`,
      referenceId: order.id,
      status: 'completed',
    },
  });

  // 7. Record commission deduction as separate transaction (for audit trail)
  if (vendorCommission > 0) {
    await tx.vendorTransaction.create({
      data: {
        walletId: wallet.id,
        vendorId: vendor.vendorId,
        type: 'commission',
        amount: -vendorCommission,
        description: `GrabGo commission (${(vendorCommissionRate * 100).toFixed(0)}%) on order ${order.orderNumber || order.id}`,
        referenceId: order.id,
        status: 'completed',
      },
    });
  }

  // 8. Update wallet balance and totals
  await tx.vendorWallet.update({
    where: { id: wallet.id },
    data: {
      balance: { increment: vendorPayout },
      totalEarnings: { increment: subtotal },
      totalCommission: { increment: vendorCommission },
    },
  });

  console.log(
    `[VendorSettlement] Settled order=${order.id}: vendor=${vendor.vendorName} ` +
      `subtotal=${subtotal} commission=${vendorCommission} (${(vendorCommissionRate * 100).toFixed(0)}%) payout=${vendorPayout}`
  );

  return {
    vendorId: vendor.vendorId,
    vendorType: vendor.vendorType,
    vendorCommission,
    vendorPayout,
    settled: true,
  };
};

module.exports = {
  calculateVendorCommission,
  resolveVendor,
  settleVendorInTransaction,
  DEFAULT_VENDOR_COMMISSION_RATE,
};
