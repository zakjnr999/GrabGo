const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');

/**
 * Middleware that validates withdrawal requests against true available balance.
 *
 * Available balance = wallet.balance - wallet.pendingWithdrawals
 *
 * Attaches `req.withdrawalContext` with the validated wallet state so the
 * downstream handler can proceed without re-querying.
 */
const withdrawalBalanceGuard = async (req, res, next) => {
  // Allow bypass if withdrawal guard feature flag is disabled
  if (!featureFlags.isRiderWithdrawalGuardEnabled) {
    // Still need basic wallet context for downstream
    try {
      const wallet = await prisma.riderWallet.findUnique({ where: { userId: req.user.id } });
      const amount = typeof req.body.amount === 'string' ? parseFloat(req.body.amount) : req.body.amount;
      req.withdrawalContext = { wallet, availableBalance: wallet?.balance || 0, requestedAmount: amount };
      return next();
    } catch (err) {
      return next();
    }
  }

  try {
    const userId = req.user.id;
    const rawAmount = req.body.amount;
    const amount = typeof rawAmount === 'string' ? parseFloat(rawAmount) : rawAmount;

    if (!amount || typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid withdrawal amount. Must be a positive number.',
      });
    }

    // Minimum withdrawal amount (GHS 50)
    const MINIMUM_WITHDRAWAL = 50;
    if (amount < MINIMUM_WITHDRAWAL) {
      return res.status(400).json({
        success: false,
        message: `Minimum withdrawal amount is GHS ${MINIMUM_WITHDRAWAL}.`,
        minimumAmount: MINIMUM_WITHDRAWAL,
      });
    }

    // Fetch wallet
    const wallet = await prisma.riderWallet.findUnique({
      where: { userId },
    });

    if (!wallet) {
      return res.status(404).json({
        success: false,
        message: 'Wallet not found. Please contact support.',
      });
    }

    const currentBalance = Number(wallet.balance) || 0;
    const pendingWithdrawals = Number(wallet.pendingWithdrawals) || 0;
    const availableBalance = currentBalance - pendingWithdrawals;

    if (amount > availableBalance) {
      return res.status(400).json({
        success: false,
        message: 'Insufficient available balance for this withdrawal.',
        walletState: {
          balance: currentBalance,
          pendingWithdrawals,
          availableBalance: Math.max(0, availableBalance),
          requestedAmount: amount,
          shortfall: Math.round((amount - availableBalance) * 100) / 100,
        },
      });
    }

    // Attach validated context for downstream handler
    req.withdrawalContext = {
      wallet,
      availableBalance,
      requestedAmount: amount,
    };

    next();
  } catch (error) {
    console.error('[WithdrawalGuard] Error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Failed to validate withdrawal request.',
    });
  }
};

module.exports = { withdrawalBalanceGuard };
