const prisma = require("../config/prisma");
const { sendToUser } = require("./fcm_service");
const { createNotification } = require("./notification_service");
const { getIO } = require("../utils/socket");

/**
 * GrabGo Credit Service
 * Manages in-app store credits for customers
 * Credits are non-withdrawable and non-transferable
 */
class CreditService {
  /**
   * Get user's current credit balance
   * @param {string} userId - User ID
   * @returns {Promise<number>} Credit balance
   */
  async getBalance(userId) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { creditBalance: true },
    });
    return user?.creditBalance || 0;
  }

  /**
   * Get user's credit transaction history
   * @param {string} userId - User ID
   * @param {object} options - Pagination options
   * @returns {Promise<object>} Transactions with pagination
   */
  async getTransactionHistory(userId, { page = 1, limit = 20 } = {}) {
    const skip = (page - 1) * limit;

    const [transactions, total] = await Promise.all([
      prisma.userCredit.findMany({
        where: { userId },
        orderBy: { createdAt: "desc" },
        skip,
        take: limit,
        select: {
          id: true,
          amount: true,
          type: true,
          description: true,
          orderId: true,
          createdAt: true,
        },
      }),
      prisma.userCredit.count({ where: { userId } }),
    ]);

    return {
      transactions,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Grant credits to a user (adds to balance)
   * @param {object} params - Grant parameters
   * @returns {Promise<object>} Transaction record
   */
  async grantCredits({
    userId,
    amount,
    type,
    description,
    orderId = null,
    referralId = null,
    adminId = null,
  }) {
    if (amount <= 0) {
      throw new Error("Credit amount must be positive");
    }

    // Use transaction to ensure atomicity
    const result = await prisma.$transaction(async (tx) => {
      // Create credit transaction record
      const creditTransaction = await tx.userCredit.create({
        data: {
          userId,
          amount,
          type,
          description,
          orderId,
          referralId,
          isUsed: false,
          isActive: true,
        },
      });

      // Update user's cached balance
      await tx.user.update({
        where: { id: userId },
        data: {
          creditBalance: { increment: amount },
        },
      });

      // Get updated balance
      const user = await tx.user.findUnique({
        where: { id: userId },
        select: { creditBalance: true },
      });

      return {
        transaction: creditTransaction,
        newBalance: user.creditBalance,
      };
    });

    console.log(
      `💰 [Credit] Granted ₵${amount.toFixed(2)} to user ${userId} (${type}). New balance: ₵${result.newBalance.toFixed(2)}`
    );

    // Send notification for credit received
    await this._sendCreditNotification(userId, amount, type, description, result.newBalance);

    return result;
  }

  /**
   * Send notification when credits are granted
   */
  async _sendCreditNotification(userId, amount, type, description, newBalance) {
    try {
      const typeLabels = {
        referral_earned: "Referral Reward",
        referral_received: "Referral Bonus",
        promotion: "Promotional Credit",
        refund: "Refund Credit",
        bonus: "Bonus Credit",
        admin_grant: "Credit Added",
      };

      const title = `💰 ${typeLabels[type] || "Credits Received"}`;
      const body = `₵${amount.toFixed(2)} has been added to your GrabGo Credits. New balance: ₵${newBalance.toFixed(2)}`;

      // Send FCM push notification
      await sendToUser(
        userId,
        { title, body },
        { type: "credit_received", amount: amount.toString(), newBalance: newBalance.toString() }
      );

      // Create in-app notification
      const io = getIO();
      if (io) {
        await createNotification(
          userId,
          "credit",
          title,
          description || body,
          { type: "credit_received", amount, newBalance, route: "/credits" },
          io
        );
      }
    } catch (error) {
      console.error("Error sending credit notification:", error.message);
    }
  }

  /**
   * Deduct credits from a user (subtracts from balance)
   * @param {object} params - Deduction parameters
   * @returns {Promise<object>} Transaction record
   */
  async deductCredits({
    userId,
    amount,
    type,
    description,
    orderId = null,
    adminId = null,
  }) {
    if (amount <= 0) {
      throw new Error("Deduction amount must be positive");
    }

    // Check current balance
    const currentBalance = await this.getBalance(userId);
    if (currentBalance < amount) {
      throw new Error(
        `Insufficient credit balance. Available: ₵${currentBalance.toFixed(2)}, Requested: ₵${amount.toFixed(2)}`
      );
    }

    // Use transaction to ensure atomicity
    const result = await prisma.$transaction(async (tx) => {
      // Create deduction transaction record (negative amount)
      const creditTransaction = await tx.userCredit.create({
        data: {
          userId,
          amount: -amount, // Negative for deductions
          type,
          description,
          orderId,
          isUsed: true,
          isActive: true,
          usedAt: new Date(),
        },
      });

      // Update user's cached balance
      await tx.user.update({
        where: { id: userId },
        data: {
          creditBalance: { decrement: amount },
        },
      });

      // Get updated balance
      const user = await tx.user.findUnique({
        where: { id: userId },
        select: { creditBalance: true },
      });

      return {
        transaction: creditTransaction,
        newBalance: user.creditBalance,
      };
    });

    console.log(
      `💸 [Credit] Deducted ₵${amount.toFixed(2)} from user ${userId} (${type}). New balance: ₵${result.newBalance.toFixed(2)}`
    );

    return result;
  }

  /**
   * Apply credits to an order at checkout
   * Returns the amount of credits to apply and remaining payment amount
   * @param {string} userId - User ID
   * @param {number} orderTotal - Total order amount
   * @param {boolean} useCredits - Whether user wants to use credits
   * @returns {Promise<object>} Credit application details
   */
  async calculateCreditApplication(userId, orderTotal, useCredits = true) {
    if (!useCredits) {
      return {
        creditsApplied: 0,
        remainingPayment: orderTotal,
        creditBalance: await this.getBalance(userId),
      };
    }

    const creditBalance = await this.getBalance(userId);
    const creditsToApply = Math.min(creditBalance, orderTotal);
    const remainingPayment = orderTotal - creditsToApply;

    return {
      creditsApplied: creditsToApply,
      remainingPayment: Math.max(0, remainingPayment),
      creditBalance,
    };
  }

  /**
   * Apply credits to an order (called after payment success or for credit-only orders)
   * @param {string} userId - User ID
   * @param {string} orderId - Order ID
   * @param {number} amount - Amount of credits to apply
   * @returns {Promise<object>} Transaction result
   */
  async applyCreditsToOrder(userId, orderId, amount) {
    if (amount <= 0) {
      return { creditsApplied: 0, newBalance: await this.getBalance(userId) };
    }

    return await this.deductCredits({
      userId,
      amount,
      type: "order_payment",
      description: `Credits applied to order`,
      orderId,
    });
  }

  /**
   * Refund order amount as credits
   * @param {string} userId - User ID
   * @param {string} orderId - Order ID
   * @param {number} amount - Refund amount
   * @param {string} reason - Refund reason
   * @returns {Promise<object>} Transaction result
   */
  async refundAsCredits(userId, orderId, amount, reason = "Order refund") {
    return await this.grantCredits({
      userId,
      amount,
      type: "refund",
      description: reason,
      orderId,
    });
  }

  /**
   * Admin grant credits to user
   * @param {object} params - Grant parameters
   * @returns {Promise<object>} Transaction result
   */
  async adminGrantCredits({ userId, amount, reason, adminId }) {
    return await this.grantCredits({
      userId,
      amount,
      type: "admin_grant",
      description: `Admin credit: ${reason}`,
      adminId,
    });
  }

  /**
   * Admin deduct credits from user
   * @param {object} params - Deduction parameters
   * @returns {Promise<object>} Transaction result
   */
  async adminDeductCredits({ userId, amount, reason, adminId }) {
    return await this.deductCredits({
      userId,
      amount,
      type: "admin_deduct",
      description: `Admin deduction: ${reason}`,
      adminId,
    });
  }

  /**
   * Grant promotional credits
   * @param {object} params - Promo parameters
   * @returns {Promise<object>} Transaction result
   */
  async grantPromoCredits({ userId, amount, promoName }) {
    return await this.grantCredits({
      userId,
      amount,
      type: "promotion",
      description: promoName || "Promotional credit",
    });
  }

  /**
   * Grant welcome credits for new users
   * @param {string} userId - User ID
   * @param {number} amount - Welcome credit amount (default ₵5)
   * @returns {Promise<object>} Transaction result
   */
  async grantWelcomeCredits(userId, amount = 5.0) {
    return await this.grantCredits({
      userId,
      amount,
      type: "bonus",
      description: "Welcome to GrabGo! 🎉",
    });
  }

  /**
   * Rollback credit usage if payment fails
   * @param {string} userId - User ID
   * @param {string} orderId - Order ID
   * @param {number} amount - Amount to restore
   * @returns {Promise<object>} Transaction result
   */
  async rollbackCreditUsage(userId, orderId, amount) {
    if (amount <= 0) return null;

    return await this.grantCredits({
      userId,
      amount,
      type: "refund",
      description: "Credit restored - payment failed",
      orderId,
    });
  }

  /**
   * Recalculate user's credit balance from transaction history
   * Used for data integrity checks
   * @param {string} userId - User ID
   * @returns {Promise<object>} Recalculation result
   */
  async recalculateBalance(userId) {
    const result = await prisma.userCredit.aggregate({
      where: { userId, isActive: true },
      _sum: { amount: true },
    });

    const calculatedBalance = result._sum.amount || 0;

    const user = await prisma.user.update({
      where: { id: userId },
      data: { creditBalance: calculatedBalance },
      select: { creditBalance: true },
    });

    console.log(
      `🔄 [Credit] Recalculated balance for user ${userId}: ₵${(calculatedBalance || 0).toFixed(2)}`
    );

    return {
      userId,
      newBalance: user.creditBalance,
    };
  }
}

module.exports = new CreditService();
