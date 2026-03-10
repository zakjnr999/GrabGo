const express = require("express");
const router = express.Router();
const { protect, authorize } = require("../middleware/auth");
const { createScopedLogger } = require("../utils/logger");
const creditService = require("../services/credit_service");
const { body, validationResult } = require("express-validator");
const console = createScopedLogger("credits_route");

const sendCreditsError = (res, error, fallbackMessage, fallbackStatus = 500) => {
  const explicitStatus = Number(error?.status);
  const status =
    Number.isInteger(explicitStatus) && explicitStatus >= 400 && explicitStatus < 600
      ? explicitStatus
      : fallbackStatus;

  const message = status >= 500 ? fallbackMessage : String(error?.message || fallbackMessage);

  return res.status(status).json({
    success: false,
    message,
  });
};

/**
 * @route   GET /api/credits/balance
 * @desc    Get current user's credit balance
 * @access  Private (Customer)
 */
router.get("/balance", protect, async (req, res) => {
  try {
    const balance = await creditService.getBalance(req.user.id);

    res.json({
      success: true,
      data: {
        balance,
        currency: "GHS",
        formatted: `₵${balance.toFixed(2)}`,
      },
    });
  } catch (error) {
    console.error("Get credit balance error:", error);
    return sendCreditsError(res, error, "Failed to get credit balance");
  }
});

/**
 * @route   GET /api/credits/transactions
 * @desc    Get user's credit transaction history
 * @access  Private (Customer)
 */
router.get("/transactions", protect, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;

    const result = await creditService.getTransactionHistory(req.user.id, {
      page: parseInt(page),
      limit: parseInt(limit),
    });

    // Format transactions for display
    const formattedTransactions = result.transactions.map((tx) => ({
      id: tx.id,
      amount: tx.amount,
      formattedAmount:
        tx.amount >= 0 ? `+₵${tx.amount.toFixed(2)}` : `-₵${Math.abs(tx.amount).toFixed(2)}`,
      type: tx.type,
      typeLabel: formatCreditType(tx.type),
      description: tx.description,
      orderId: tx.orderId,
      createdAt: tx.createdAt,
      isCredit: tx.amount >= 0,
    }));

    res.json({
      success: true,
      data: {
        transactions: formattedTransactions,
        pagination: result.pagination,
      },
    });
  } catch (error) {
    console.error("Get credit transactions error:", error);
    return sendCreditsError(res, error, "Failed to get credit transactions");
  }
});

/**
 * @route   POST /api/credits/calculate
 * @desc    Calculate credit application for checkout
 * @access  Private (Customer)
 */
router.post(
  "/calculate",
  protect,
  [body("orderTotal").isFloat({ min: 0 }).withMessage("Order total must be a positive number")],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    try {
      const { orderTotal, useCredits = true } = req.body;

      const result = await creditService.calculateCreditApplication(
        req.user.id,
        orderTotal,
        useCredits
      );

      res.json({
        success: true,
        data: {
          ...result,
          formattedCreditsApplied: `₵${result.creditsApplied.toFixed(2)}`,
          formattedRemainingPayment: `₵${result.remainingPayment.toFixed(2)}`,
          formattedCreditBalance: `₵${result.creditBalance.toFixed(2)}`,
          formattedAvailableBalance: `₵${(result.availableBalance ?? result.creditBalance).toFixed(2)}`,
        },
      });
    } catch (error) {
      console.error("Calculate credit application error:", error);
      return sendCreditsError(res, error, "Failed to calculate credit application");
    }
  }
);

// ==================== ADMIN ENDPOINTS ====================

/**
 * @route   GET /api/credits/admin/user/:userId
 * @desc    Get a user's credit balance and history (Admin)
 * @access  Private (Admin)
 */
router.get("/admin/user/:userId", protect, authorize("admin"), async (req, res) => {
  try {
    const { userId } = req.params;
    const { page = 1, limit = 20 } = req.query;

    const [balance, history] = await Promise.all([
      creditService.getBalance(userId),
      creditService.getTransactionHistory(userId, {
        page: parseInt(page),
        limit: parseInt(limit),
      }),
    ]);

    res.json({
      success: true,
      data: {
        userId,
        balance,
        formattedBalance: `₵${balance.toFixed(2)}`,
        transactions: history.transactions,
        pagination: history.pagination,
      },
    });
  } catch (error) {
    console.error("Admin get user credits error:", error);
    return sendCreditsError(res, error, "Failed to get user credits");
  }
});

/**
 * @route   POST /api/credits/admin/grant
 * @desc    Grant credits to a user (Admin)
 * @access  Private (Admin)
 */
router.post(
  "/admin/grant",
  protect,
  authorize("admin"),
  [
    body("userId").notEmpty().withMessage("User ID is required"),
    body("amount").isFloat({ min: 0.01 }).withMessage("Amount must be greater than 0"),
    body("reason").notEmpty().withMessage("Reason is required"),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    try {
      const { userId, amount, reason } = req.body;

      const result = await creditService.adminGrantCredits({
        userId,
        amount: parseFloat(amount),
        reason,
        adminId: req.user.id,
      });

      res.json({
        success: true,
        message: `Successfully granted ₵${parseFloat(amount).toFixed(2)} to user`,
        data: {
          transactionId: result.transaction.id,
          newBalance: result.newBalance,
          formattedNewBalance: `₵${result.newBalance.toFixed(2)}`,
        },
      });
    } catch (error) {
      console.error("Admin grant credits error:", error);
      return sendCreditsError(res, error, "Failed to grant credits");
    }
  }
);

/**
 * @route   POST /api/credits/admin/deduct
 * @desc    Deduct credits from a user (Admin)
 * @access  Private (Admin)
 */
router.post(
  "/admin/deduct",
  protect,
  authorize("admin"),
  [
    body("userId").notEmpty().withMessage("User ID is required"),
    body("amount").isFloat({ min: 0.01 }).withMessage("Amount must be greater than 0"),
    body("reason").notEmpty().withMessage("Reason is required"),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    try {
      const { userId, amount, reason } = req.body;

      const result = await creditService.adminDeductCredits({
        userId,
        amount: parseFloat(amount),
        reason,
        adminId: req.user.id,
      });

      res.json({
        success: true,
        message: `Successfully deducted ₵${parseFloat(amount).toFixed(2)} from user`,
        data: {
          transactionId: result.transaction.id,
          newBalance: result.newBalance,
          formattedNewBalance: `₵${result.newBalance.toFixed(2)}`,
        },
      });
    } catch (error) {
      console.error("Admin deduct credits error:", error);

      if (String(error?.message || "").includes("Insufficient")) {
        return res.status(400).json({
          success: false,
          message: String(error.message),
        });
      }

      return sendCreditsError(res, error, "Failed to deduct credits");
    }
  }
);

/**
 * @route   POST /api/credits/admin/recalculate/:userId
 * @desc    Recalculate user's credit balance from transaction history
 * @access  Private (Admin)
 */
router.post("/admin/recalculate/:userId", protect, authorize("admin"), async (req, res) => {
  try {
    const { userId } = req.params;

    const result = await creditService.recalculateBalance(userId);

    res.json({
      success: true,
      message: "Credit balance recalculated",
      data: {
        userId: result.userId,
        newBalance: result.newBalance,
        formattedNewBalance: `₵${result.newBalance.toFixed(2)}`,
      },
    });
  } catch (error) {
    console.error("Recalculate balance error:", error);
    return sendCreditsError(res, error, "Failed to recalculate balance");
  }
});

// ==================== HELPER FUNCTIONS ====================

/**
 * Format credit type for display
 */
function formatCreditType(type) {
  const labels = {
    referral_earned: "Referral Reward",
    referral_received: "Referral Bonus",
    promotion: "Promotional Credit",
    refund: "Refund",
    bonus: "Bonus",
    admin_grant: "Credit Added",
    admin_deduct: "Credit Deducted",
    order_payment: "Order Payment",
  };
  return labels[type] || type;
}

module.exports = router;
