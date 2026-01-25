const prisma = require('../config/prisma');
const { sendReferralNotification, sendMilestoneBonusNotification } = require('./fcm_service');
const { createNotification } = require('./notification_service');
const { getIO } = require('../utils/socket');

// Referral reward constants
const REFERRAL_REWARD_AMOUNT = 10.00;
const MILESTONE_BONUS_AMOUNT = 5.00;

class ReferralService {
    /**
     * Complete referral when referee places first order
     * @param {String} userId - Referee user ID
     * @param {String} orderId - Order ID
     * @param {Number} orderAmount - Order total amount
     * @param {Object} io - Socket.IO instance (optional)
     * @returns {Object} - Result of referral completion
     */
    static async completeReferral(userId, orderId, orderAmount, io = null) {
        try {
            // Find pending referral for this user
            const referral = await prisma.referral.findFirst({
                where: {
                    refereeId: userId,
                    status: 'pending_order'
                }
            });

            if (!referral) {
                return { success: false, message: 'No pending referral found' };
            }

            // Check if referral expired
            if (referral.expiresAt && referral.expiresAt < new Date()) {
                await prisma.referral.update({
                    where: { id: referral.id },
                    data: { status: 'expired' }
                });
                return { success: false, message: 'Referral expired' };
            }

            // Check minimum order value (GHS 20)
            if (orderAmount < 20) {
                return { success: false, message: 'Order amount below minimum for referral discount' };
            }

            // ATOMIC UPDATE: Use transaction
            const result = await prisma.$transaction(async (tx) => {
                // Create credit for referrer (expires in 90 days)
                const referrerCreditExpiry = new Date();
                referrerCreditExpiry.setDate(referrerCreditExpiry.getDate() + 90);

                const referrerCredit = await tx.userCredit.create({
                    data: {
                        userId: referral.referrerId,
                        amount: REFERRAL_REWARD_AMOUNT,
                        type: 'referral_earned',
                        referralId: referral.id,
                        expiresAt: referrerCreditExpiry,
                        description: `Referral bonus - friend completed first order`
                    }
                });

                // Update referral status
                await tx.referral.update({
                    where: { id: referral.id },
                    data: {
                        status: 'completed',
                        refereeOrderId: orderId,
                        referrerCreditId: referrerCredit.id,
                        referrerCreditedAt: new Date(),
                        completedAt: new Date()
                    }
                });

                // Update referral code stats
                const referrerCode = await tx.referralCode.update({
                    where: { userId: referral.referrerId },
                    data: {
                        completedReferrals: { increment: 1 },
                        totalEarned: { increment: REFERRAL_REWARD_AMOUNT }
                    }
                });

                // Check for milestone bonus (every 5 completed referrals)
                let awardedBonus = false;
                if (referrerCode.completedReferrals % 5 === 0) {
                    awardedBonus = true;
                    const bonusExpiry = new Date();
                    bonusExpiry.setDate(bonusExpiry.getDate() + 90);

                    await tx.userCredit.create({
                        data: {
                            userId: referral.referrerId,
                            amount: MILESTONE_BONUS_AMOUNT,
                            type: 'bonus',
                            expiresAt: bonusExpiry,
                            description: `Milestone bonus - ${referrerCode.completedReferrals} referrals completed!`
                        }
                    });

                    await tx.referralCode.update({
                        where: { id: referrerCode.id },
                        data: { totalEarned: { increment: MILESTONE_BONUS_AMOUNT } }
                    });
                }

                return { referrerCode, awardedBonus };
            });

            // Send notifications (async, outside transaction)
            try {
                const referee = await prisma.user.findUnique({
                    where: { id: userId },
                    select: { username: true }
                });
                const refereeName = referee?.username || 'Your friend';

                // 1. Referral success notification
                await sendReferralNotification(referral.referrerId, refereeName, REFERRAL_REWARD_AMOUNT);

                const ioInstance = io || getIO();
                if (ioInstance) {
                    await createNotification(
                        referral.referrerId,
                        'referral_completed',
                        '🎉 Referral Success!',
                        `${refereeName} completed their first order. You earned GHS ${REFERRAL_REWARD_AMOUNT}!`,
                        {
                            refereeName,
                            rewardAmount: REFERRAL_REWARD_AMOUNT,
                            route: '/referral'
                        },
                        ioInstance
                    );
                }

                // 2. Milestone bonus notification
                if (result.awardedBonus) {
                    await sendMilestoneBonusNotification(
                        referral.referrerId,
                        result.referrerCode.completedReferrals,
                        MILESTONE_BONUS_AMOUNT
                    );

                    if (ioInstance) {
                        await createNotification(
                            referral.referrerId,
                            'milestone_bonus',
                            '🎉 Milestone Reached!',
                            `Congrats! You've completed ${result.referrerCode.completedReferrals} referrals. Bonus GHS ${MILESTONE_BONUS_AMOUNT} added!`,
                            {
                                milestone: result.referrerCode.completedReferrals,
                                bonusAmount: MILESTONE_BONUS_AMOUNT,
                                route: '/referral'
                            },
                            ioInstance
                        );
                    }
                }
            } catch (notifError) {
                console.error('❌ Error sending referral notifications:', notifError.message);
            }

            return {
                success: true,
                message: 'Referral completed successfully',
                referrerId: referral.referrerId,
                creditAmount: REFERRAL_REWARD_AMOUNT
            };
        } catch (error) {
            console.error('Error completing referral:', error);
            return { success: false, message: 'Error completing referral' };
        }
    }

    /**
     * Apply available credits to an order
     * @param {String} userId - User ID
     * @param {Number} orderAmount - Order total amount
     * @returns {Object} - Applied credits and new total
     */
    static async applyCreditsToOrder(userId, orderAmount) {
        try {
            // Get available credits (oldest first - FIFO)
            const credits = await prisma.userCredit.findMany({
                where: {
                    userId: userId,
                    isActive: true,
                    isUsed: false,
                    OR: [
                        { expiresAt: null },
                        { expiresAt: { gt: new Date() } }
                    ]
                },
                orderBy: { expiresAt: 'asc' }
            });

            if (credits.length === 0) {
                return {
                    appliedAmount: 0,
                    newTotal: orderAmount,
                    creditsUsed: []
                };
            }

            let remainingAmount = orderAmount;
            let appliedAmount = 0;
            const creditsUsed = [];

            for (const credit of credits) {
                if (remainingAmount <= 0) break;

                // Only use credits that can be fully consumed
                if (credit.amount <= remainingAmount) {
                    appliedAmount += credit.amount;
                    remainingAmount -= credit.amount;

                    creditsUsed.push({
                        creditId: credit.id,
                        amount: credit.amount
                    });
                }
            }

            return {
                appliedAmount: parseFloat(appliedAmount.toFixed(2)),
                newTotal: parseFloat(Math.max(0, orderAmount - appliedAmount).toFixed(2)),
                creditsUsed
            };
        } catch (error) {
            console.error('Error applying credits:', error);
            return {
                appliedAmount: 0,
                newTotal: orderAmount,
                creditsUsed: []
            };
        }
    }

    /**
     * Mark credits as used after order is confirmed
     * @param {Array} creditsUsed - Array of {creditId, amount}
     * @param {String} orderId - Order ID
     */
    static async markCreditsAsUsed(creditsUsed, orderId) {
        try {
            await prisma.$transaction(
                creditsUsed.map(({ creditId }) =>
                    prisma.userCredit.update({
                        where: { id: creditId },
                        data: {
                            isUsed: true,
                            orderId: orderId,
                            isActive: false,
                            usedAt: new Date()
                        }
                    })
                )
            );
            return { success: true };
        } catch (error) {
            console.error('Error marking credits as used:', error);
            return { success: false };
        }
    }

    /**
     * Get user's total available credit balance
     * @param {String} userId - User ID
     * @returns {Number} - Total available credit
     */
    static async getUserCreditBalance(userId) {
        try {
            const credits = await prisma.userCredit.findMany({
                where: {
                    userId: userId,
                    isActive: true,
                    isUsed: false,
                    OR: [
                        { expiresAt: null },
                        { expiresAt: { gt: new Date() } }
                    ]
                }
            });

            const total = credits.reduce((sum, credit) => sum + credit.amount, 0);
            return parseFloat(total.toFixed(2));
        } catch (error) {
            console.error('Error getting credit balance:', error);
            return 0;
        }
    }

    /**
     * Expire old referrals and credits (run as cron job)
     */
    static async expireOldRecords() {
        try {
            const now = new Date();

            // Expire old referrals
            await prisma.referral.updateMany({
                where: {
                    status: 'pending_order',
                    expiresAt: { lt: now }
                },
                data: {
                    status: 'expired'
                }
            });

            // Deactivate expired credits
            await prisma.userCredit.updateMany({
                where: {
                    isActive: true,
                    isUsed: false,
                    expiresAt: { lt: now }
                },
                data: {
                    isActive: false
                }
            });

            console.log('Expired old referrals and credits');
            return { success: true };
        } catch (error) {
            console.error('Error expiring records:', error);
            return { success: false };
        }
    }
}

module.exports = ReferralService;
