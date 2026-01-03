const Referral = require('../models/Referral');
const ReferralCode = require('../models/ReferralCode');
const UserCredit = require('../models/UserCredit');
const User = require('../models/User');
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
            const referral = await Referral.findOne({
                referee: userId,
                status: 'pending_order'
            });

            if (!referral) {
                return { success: false, message: 'No pending referral found' };
            }

            // Check if referral expired
            if (referral.expiresAt < new Date()) {
                await Referral.findByIdAndUpdate(referral._id, { status: 'expired' });
                return { success: false, message: 'Referral expired' };
            }

            // Check minimum order value (GHS 20)
            if (orderAmount < 20) {
                return { success: false, message: 'Order amount below minimum for referral discount' };
            }

            // Create credit for referrer (expires in 90 days)
            const referrerCreditExpiry = new Date();
            referrerCreditExpiry.setDate(referrerCreditExpiry.getDate() + 90);

            const referrerCredit = await UserCredit.create({
                user: referral.referrer,
                amount: REFERRAL_REWARD_AMOUNT,
                source: 'referral_earned',
                referralId: referral._id,
                expiresAt: referrerCreditExpiry,
                description: `Referral bonus - friend completed first order`
            });

            // Update referral status
            await Referral.findByIdAndUpdate(referral._id, {
                status: 'completed',
                refereeOrderId: orderId,
                referrerCreditId: referrerCredit._id,
                referrerCreditedAt: new Date(),
                completedAt: new Date()
            });

            // Update referral code stats and get the NEW value atomically
            const referrerCode = await ReferralCode.findOneAndUpdate(
                { user: referral.referrer },
                {
                    $inc: {
                        completedReferrals: 1,
                        totalEarned: REFERRAL_REWARD_AMOUNT
                    }
                },
                { new: true } // Return updated document
            );

            // Check for milestone bonus (every 5 completed referrals)
            if (referrerCode && referrerCode.completedReferrals % 5 === 0) {
                // Award milestone bonus (GHS 5)
                const bonusExpiry = new Date();
                bonusExpiry.setDate(bonusExpiry.getDate() + 90);

                await UserCredit.create({
                    user: referral.referrer,
                    amount: MILESTONE_BONUS_AMOUNT,
                    source: 'bonus',
                    expiresAt: bonusExpiry,
                    description: `Milestone bonus - ${referrerCode.completedReferrals} referrals completed!`
                });

                await ReferralCode.findByIdAndUpdate(referrerCode._id, {
                    $inc: { totalEarned: MILESTONE_BONUS_AMOUNT }
                });

                // Send milestone notifications (FCM + in-app)
                try {
                    // FCM push notification
                    await sendMilestoneBonusNotification(
                        referral.referrer,
                        referrerCode.completedReferrals,
                        MILESTONE_BONUS_AMOUNT
                    );

                    // In-app notification with WebSocket
                    const ioInstance = io || getIO();
                    if (ioInstance) {
                        await createNotification(
                            referral.referrer,
                            'milestone_bonus',
                            '🎉 Milestone Reached!',
                            `Congrats! You've completed ${referrerCode.completedReferrals} referrals. Bonus GHS ${MILESTONE_BONUS_AMOUNT} added!`,
                            {
                                milestone: referrerCode.completedReferrals,
                                bonusAmount: MILESTONE_BONUS_AMOUNT,
                                route: '/referral'
                            },
                            ioInstance
                        );
                    }
                    console.log(`✅ Milestone notifications sent to ${referral.referrer}`);
                } catch (notifError) {
                    console.error('❌ Error sending milestone notification:', notifError.message);
                }
            }

            // Send referral notifications (FCM + in-app)
            try {
                const referee = await User.findById(userId).select('username');
                const refereeName = referee?.username || 'Your friend';

                // FCM push notification
                await sendReferralNotification(referral.referrer, refereeName, REFERRAL_REWARD_AMOUNT);

                // In-app notification with WebSocket
                const ioInstance = io || getIO();
                if (ioInstance) {
                    await createNotification(
                        referral.referrer,
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
                console.log(`✅ Referral notifications sent to ${referral.referrer}`);
            } catch (notifError) {
                console.error('❌ Error sending referral notification:', notifError.message);
                // Don't fail the whole operation if notification fails
            }

            return {
                success: true,
                message: 'Referral completed successfully',
                referrerId: referral.referrer,
                creditAmount: 10.00
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
            const credits = await UserCredit.find({
                user: userId,
                isActive: true,
                usedAt: null,
                expiresAt: { $gt: new Date() }
            }).sort({ expiresAt: 1 });

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
                // This prevents losing unused credit portions
                if (credit.amount <= remainingAmount) {
                    appliedAmount += credit.amount;
                    remainingAmount -= credit.amount;

                    creditsUsed.push({
                        creditId: credit._id,
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
            for (const { creditId } of creditsUsed) {
                await UserCredit.findByIdAndUpdate(creditId, {
                    usedAt: new Date(),
                    orderId: orderId,
                    isActive: false
                });
            }
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
            const credits = await UserCredit.find({
                user: userId,
                isActive: true,
                usedAt: null,
                expiresAt: { $gt: new Date() }
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
            await Referral.updateMany(
                {
                    status: 'pending_order',
                    expiresAt: { $lt: now }
                },
                {
                    status: 'expired'
                }
            );

            // Deactivate expired credits
            await UserCredit.updateMany(
                {
                    isActive: true,
                    usedAt: null,
                    expiresAt: { $lt: now }
                },
                {
                    isActive: false
                }
            );

            console.log('Expired old referrals and credits');
            return { success: true };
        } catch (error) {
            console.error('Error expiring records:', error);
            return { success: false };
        }
    }
}

module.exports = ReferralService;
