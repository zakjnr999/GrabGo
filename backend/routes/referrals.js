const express = require('express');
const router = express.Router();
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const { referralApplyRateLimit } = require('../middleware/fraud_rate_limit');
const {
    ACTION_TYPES,
    buildFraudContextFromRequest,
    fraudDecisionService,
    applyFraudDecision,
} = require('../services/fraud');

// Helper function to generate referral code
const generateReferralCode = async () => {
    // Characters to use: uppercase letters and numbers (excluding similar-looking ones)
    // Excluded: 0, O, I, 1, L to avoid confusion
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    // Try to generate a unique 8-character code
    for (let attempt = 0; attempt < 20; attempt++) {
        let code = '';
        for (let i = 0; i < 8; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }

        // Check if code already exists
        const exists = await prisma.referralCode.findUnique({
            where: { code }
        });
        if (!exists) {
            return code;
        }
    }

    // Fallback: use timestamp-based code (very unlikely to reach here)
    const timestamp = Date.now().toString(36).toUpperCase();
    const randomSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    return `${timestamp}${randomSuffix}`.substring(0, 8);
};

// @route   GET /api/referral/my-code
// @desc    Get user's referral code and stats
// @access  Private
router.get('/my-code', protect, async (req, res) => {
    try {
        let referralCode = await prisma.referralCode.findUnique({
            where: { userId: req.user.id }
        });

        // Generate code if doesn't exist
        if (!referralCode) {
            const code = await generateReferralCode();

            referralCode = await prisma.referralCode.create({
                data: {
                    userId: req.user.id,
                    code
                }
            });
        }

        // Get referral stats
        const totalReferrals = await prisma.referral.count({
            where: { referrerId: req.user.id }
        });
        const completedReferrals = await prisma.referral.count({
            where: {
                referrerId: req.user.id,
                status: 'completed'
            }
        });
        const pendingReferrals = await prisma.referral.count({
            where: {
                referrerId: req.user.id,
                status: 'pending_order'
            }
        });

        // Get available credits
        const credits = await prisma.userCredit.findMany({
            where: {
                userId: req.user.id,
                isActive: true,
                isUsed: false,
                expiresAt: { gt: new Date() }
            }
        });
        const availableCredit = credits.reduce((sum, credit) => sum + credit.amount, 0);

        res.json({
            code: referralCode.code,
            shareUrl: `${process.env.APP_URL || 'https://grabgo.app'}/r/${referralCode.code}`,
            totalReferrals,
            completedReferrals,
            pendingReferrals,
            totalEarned: referralCode.totalEarned,
            availableCredit: availableCredit.toFixed(2)
        });
    } catch (error) {
        console.error('Error getting referral code:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @route   GET /api/referral/my-referrals
// @desc    Get list of user's referrals
// @access  Private
router.get('/my-referrals', protect, async (req, res) => {
    try {
        const referrals = await prisma.referral.findMany({
            where: { referrerId: req.user.id },
            include: {
                referee: {
                    select: { username: true }
                }
            },
            orderBy: { createdAt: 'desc' },
            take: 50
        });

        const formattedReferrals = referrals.map(ref => ({
            id: ref.id,
            refereeName: ref.referee ? ref.referee.username : 'User',
            status: ref.status,
            creditEarned: ref.status === 'completed' ? ref.rewardAmount : 0,
            createdAt: ref.createdAt,
            completedAt: ref.completedAt
        }));

        res.json({ referrals: formattedReferrals });
    } catch (error) {
        console.error('Error getting referrals:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @route   POST /api/referral/validate
// @desc    Validate a referral code
// @access  Public
router.post('/validate', async (req, res) => {
    try {
        const { code } = req.body;

        if (!code) {
            return res.status(400).json({ message: 'Referral code is required' });
        }

        const referralCode = await prisma.referralCode.findUnique({
            where: { code: code.toUpperCase() },
            include: { user: { select: { username: true } } }
        });

        if (!referralCode) {
            return res.json({
                valid: false,
                message: 'Invalid referral code'
            });
        }

        res.json({
            valid: true,
            referrerName: referralCode.user?.username || 'Unknown',
            discount: 10.00, // Hardcoded as in original
            minOrderValue: 20.00, // Hardcoded as in original
            validDays: 7, // Hardcoded as in original
            isSystemCode: false
        });
    } catch (error) {
        console.error('Error validating referral code:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @route   POST /api/referral/apply
// @desc    Apply referral code to new user
// @access  Private
router.post('/apply', protect, referralApplyRateLimit, async (req, res) => {
    try {
        const { code } = req.body;

        if (!code) {
            return res.status(400).json({ message: 'Referral code is required' });
        }

        const fraudContext = buildFraudContextFromRequest({
            req,
            actionType: ACTION_TYPES.REFERRAL_APPLY,
            actorType: req.user.role || 'customer',
            actorId: req.user.id,
            extras: {
                referralCode: code ? String(code).toUpperCase() : null,
            },
        });

        const fraudDecision = await fraudDecisionService.evaluate({
            actionType: ACTION_TYPES.REFERRAL_APPLY,
            actorType: req.user.role || 'customer',
            actorId: req.user.id,
            context: fraudContext,
        });

        const fraudGate = applyFraudDecision({
            req,
            res,
            decision: fraudDecision,
            actionType: ACTION_TYPES.REFERRAL_APPLY,
        });
        if (fraudGate.blocked || fraudGate.challenged) return;

        // Check if user already has a referral
        const existingReferral = await prisma.referral.findFirst({
            where: { refereeId: req.user.id }
        });
        if (existingReferral) {
            return res.status(400).json({ message: 'You have already used a referral code' });
        }

        // Find referral code
        const referralCode = await prisma.referralCode.findUnique({
            where: { code: code.toUpperCase() }
        });

        if (!referralCode) {
            return res.status(400).json({ message: 'Invalid referral code' });
        }

        // Can't refer yourself
        if (referralCode.userId === req.user.id) {
            return res.status(400).json({ message: 'You cannot use your own referral code' });
        }

        const referralExpiry = new Date();
        referralExpiry.setDate(referralExpiry.getDate() + 7);

        // Transaction to apply referral and create credit
        const result = await prisma.$transaction(async (tx) => {
            // Create referral record
            const referral = await tx.referral.create({
                data: {
                    referrerId: referralCode.userId,
                    refereeId: req.user.id,
                    referralCode: code.toUpperCase(),
                    status: 'pending_order',
                    expiresAt: referralExpiry,
                }
            });

            // Create referee credit
            const refereeCreditExpiry = new Date();
            refereeCreditExpiry.setDate(refereeCreditExpiry.getDate() + 7);

            const refereeCredit = await tx.userCredit.create({
                data: {
                    userId: req.user.id,
                    amount: 10.00,
                    type: 'referral_received',
                    referralId: referral.id,
                    expiresAt: refereeCreditExpiry,
                    description: `Referral credit from ${code}`
                }
            });

            // Update referral with credit ID (if we wanted to track it, though schema doesn't have refereeCreditId yet, wait it doesn't)
            // Actually schema has referrerCreditId but not refereeCreditId? Let's check.

            // Update referral code stats
            await tx.referralCode.update({
                where: { id: referralCode.id },
                data: { usageCount: { increment: 1 } }
            });

            return { referral, refereeCredit };
        });

        res.json({
            success: true,
            message: 'Referral code applied! You have GHS 10 off your first order.',
            discount: 10.00,
            expiresAt: result.refereeCredit.expiresAt
        });
    } catch (error) {
        console.error('Error applying referral code:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @route   GET /api/referral/available-credits
// @desc    Get user's available credits
// @access  Private
router.get('/available-credits', protect, async (req, res) => {
    try {
        const credits = await prisma.userCredit.findMany({
            where: {
                userId: req.user.id,
                isActive: true,
                isUsed: false,
                expiresAt: { gt: new Date() }
            },
            orderBy: { expiresAt: 'asc' }
        });

        const totalAmount = credits.reduce((sum, credit) => sum + credit.amount, 0);

        res.json({
            credits: credits.map(c => ({
                id: c.id,
                amount: c.amount,
                source: c.type,
                expiresAt: c.expiresAt,
                description: c.description
            })),
            totalAmount: totalAmount.toFixed(2)
        });
    } catch (error) {
        console.error('Error getting credits:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
