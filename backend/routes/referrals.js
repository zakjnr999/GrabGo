const express = require('express');
const router = express.Router();
const ReferralCode = require('../models/ReferralCode');
const Referral = require('../models/Referral');
const UserCredit = require('../models/UserCredit');
const User = require('../models/User');
const { protect } = require('../middleware/auth');

// Helper function to generate referral code
const generateReferralCode = async (firstName) => {
    const cleanName = firstName.toUpperCase().replace(/[^A-Z]/g, '');
    const shortName = cleanName.substring(0, Math.min(cleanName.length, 6));

    // Try with random 4 digits
    for (let i = 0; i < 10; i++) {
        const suffix = Math.floor(Math.random() * 9000) + 1000; // 1000-9999
        const code = `${shortName}${suffix}`;

        const exists = await ReferralCode.findOne({ code });
        if (!exists) {
            return code;
        }
    }

    // Fallback: use timestamp
    const timestamp = Date.now() % 10000;
    return `${shortName}${timestamp}`;
};

// @route   GET /api/referral/my-code
// @desc    Get user's referral code and stats
// @access  Private
router.get('/my-code', protect, async (req, res) => {
    try {
        let referralCode = await ReferralCode.findOne({ user: req.user._id });

        // Generate code if doesn't exist
        if (!referralCode) {
            const user = await User.findById(req.user._id);
            const code = await generateReferralCode(user.username || 'USER');

            referralCode = await ReferralCode.create({
                user: req.user._id,
                code
            });
        }

        // Get referral stats
        const totalReferrals = await Referral.countDocuments({ referrer: req.user._id });
        const completedReferrals = await Referral.countDocuments({
            referrer: req.user._id,
            status: 'completed'
        });
        const pendingReferrals = await Referral.countDocuments({
            referrer: req.user._id,
            status: 'pending_order'
        });

        // Get available credits
        const credits = await UserCredit.find({
            user: req.user._id,
            isActive: true,
            usedAt: null,
            expiresAt: { $gt: new Date() }
        });
        const availableCredit = credits.reduce((sum, credit) => sum + credit.amount, 0);

        res.json({
            code: referralCode.code,
            shareUrl: `${process.env.APP_URL}/r/${referralCode.code}`,
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
        const referrals = await Referral.find({ referrer: req.user._id })
            .populate('referee', 'username')
            .sort({ createdAt: -1 })
            .limit(50);

        const formattedReferrals = referrals.map(ref => ({
            id: ref._id,
            refereeName: ref.referee ? ref.referee.username : 'User',
            status: ref.status,
            creditEarned: ref.status === 'completed' ? ref.referrerCreditAmount : 0,
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

        const referralCode = await ReferralCode.findOne({
            code: code.toUpperCase(),
            isActive: true
        }).populate('user', 'username');

        if (!referralCode) {
            return res.json({
                valid: false,
                message: 'Invalid referral code'
            });
        }

        res.json({
            valid: true,
            referrerName: referralCode.user.username,
            discount: 10.00,
            minOrderValue: 20.00,
            validDays: 7
        });
    } catch (error) {
        console.error('Error validating referral code:', error);
        res.status(500).json({ message: 'Server error' });
    }
});

// @route   POST /api/referral/apply
// @desc    Apply referral code to new user
// @access  Private
router.post('/apply', protect, async (req, res) => {
    try {
        const { code } = req.body;

        if (!code) {
            return res.status(400).json({ message: 'Referral code is required' });
        }

        // Check if user already has a referral
        const existingReferral = await Referral.findOne({ referee: req.user._id });
        if (existingReferral) {
            return res.status(400).json({ message: 'You have already used a referral code' });
        }

        // Find referral code
        const referralCode = await ReferralCode.findOne({
            code: code.toUpperCase(),
            isActive: true
        });

        if (!referralCode) {
            return res.status(400).json({ message: 'Invalid referral code' });
        }

        // Can't refer yourself
        if (referralCode.user.toString() === req.user._id.toString()) {
            return res.status(400).json({ message: 'You cannot use your own referral code' });
        }

        // Create referee credit (expires in 7 days)
        const refereeCreditExpiry = new Date();
        refereeCreditExpiry.setDate(refereeCreditExpiry.getDate() + 7);

        const refereeCredit = await UserCredit.create({
            user: req.user._id,
            amount: 10.00,
            source: 'referral_received',
            expiresAt: refereeCreditExpiry,
            description: `Referral credit from ${code}`
        });

        // Create referral record (expires in 7 days for referee to complete order)
        const referralExpiry = new Date();
        referralExpiry.setDate(referralExpiry.getDate() + 7);

        const referral = await Referral.create({
            referrer: referralCode.user,
            referee: req.user._id,
            referralCode: code.toUpperCase(),
            status: 'pending_order',
            refereeCreditId: refereeCredit._id,
            expiresAt: referralExpiry,
            deviceId: req.body.deviceId || null,
            ipAddress: req.ip || null
        });

        // Update referral code stats
        await ReferralCode.findByIdAndUpdate(referralCode._id, {
            $inc: { totalReferrals: 1 }
        });

        res.json({
            success: true,
            message: 'Referral code applied! You have GHS 10 off your first order.',
            discount: 10.00,
            expiresAt: refereeCreditExpiry
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
        const credits = await UserCredit.find({
            user: req.user._id,
            isActive: true,
            usedAt: null,
            expiresAt: { $gt: new Date() }
        }).sort({ expiresAt: 1 }); // Oldest first (FIFO)

        const totalAmount = credits.reduce((sum, credit) => sum + credit.amount, 0);

        res.json({
            credits: credits.map(c => ({
                id: c._id,
                amount: c.amount,
                source: c.source,
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
