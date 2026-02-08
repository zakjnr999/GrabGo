const express = require('express');
const { body, validationResult } = require('express-validator');
const { protect, authorize } = require('../middleware/auth');
const prisma = require('../config/prisma');
const {
    validatePromoCode,
    applyPromoCode,
    createPromoCode,
    getAvailablePromoCodes,
    getAllPromoCodes,
    deactivatePromoCode
} = require('../services/promo_service');

const router = express.Router();

/**
 * @route   POST /api/promo/validate-public
 * @desc    Validate a promo code without auth (for signup)
 * @access  Public
 */
router.post('/validate-public', [
    body('code').notEmpty().withMessage('Promo code is required')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                errors: errors.array()
            });
        }

        const { code } = req.body;
        const promo = await prisma.promoCode.findUnique({
            where: { code: code.toUpperCase() },
            include: { targetedUsers: { select: { id: true } } }
        });

        if (!promo || !promo.isActive) {
            return res.status(400).json({
                success: false,
                valid: false,
                error: 'Invalid or inactive promo code'
            });
        }

        const now = new Date();
        if (promo.startDate && now < promo.startDate) {
            return res.status(400).json({
                success: false,
                valid: false,
                error: 'This promo code is not yet active'
            });
        }
        if (promo.endDate && now > promo.endDate) {
            return res.status(400).json({
                success: false,
                valid: false,
                error: 'This promo code has expired'
            });
        }

        if (promo.maxUses !== null && promo.currentUses >= promo.maxUses) {
            return res.status(400).json({
                success: false,
                valid: false,
                error: 'This promo code has reached its usage limit'
            });
        }

        if (promo.targetedUsers.length > 0) {
            return res.status(400).json({
                success: false,
                valid: false,
                error: 'This promo code is only available to selected users'
            });
        }

        const creditMessage = promo.type === 'fixed'
            ? `Promo code applied. You'll receive GHS ${promo.value} credits after signup.`
            : 'Promo code applied. Use it at checkout.';

        return res.json({
            success: true,
            valid: true,
            promo: {
                code: promo.code,
                type: promo.type,
                value: promo.value,
                minOrderAmount: promo.minOrderAmount,
                maxDiscountAmount: promo.maxDiscountAmount,
                applicableOrderTypes: promo.applicableOrderTypes,
                firstOrderOnly: promo.firstOrderOnly
            },
            message: promo.firstOrderOnly ? creditMessage : creditMessage
        });
    } catch (error) {
        console.error('Error validating promo code (public):', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to validate promo code'
        });
    }
});

/**
 * @route   POST /api/promo/validate
 * @desc    Validate a promo code
 * @access  Protected
 */
router.post('/validate', protect, [
    body('code').notEmpty().withMessage('Promo code is required'),
    body('orderAmount').isNumeric().withMessage('Order amount must be a number'),
    body('orderType').isIn(['food', 'grocery']).withMessage('Invalid order type')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                errors: errors.array()
            });
        }

        const { code, orderAmount, orderType } = req.body;
        const result = await validatePromoCode(
            code,
            req.user.id,
            parseFloat(orderAmount),
            orderType
        );

        if (result.valid) {
            res.json({
                success: true,
                valid: true,
                discount: result.discount,
                type: result.type,
                message: result.message
            });
        } else {
            res.status(400).json({
                success: false,
                valid: false,
                error: result.error
            });
        }
    } catch (error) {
        console.error('Error validating promo code:', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to validate promo code'
        });
    }
});

/**
 * @route   POST /api/promo/apply
 * @desc    Apply a promo code to an order
 * @access  Protected
 */
router.post('/apply', protect, [
    body('code').notEmpty().withMessage('Promo code is required'),
    body('orderId').notEmpty().withMessage('Order ID is required'),
    body('discountAmount').isNumeric().withMessage('Discount amount must be a number')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                errors: errors.array()
            });
        }

        const { code, orderId, discountAmount } = req.body;
        const result = await applyPromoCode(
            code,
            req.user.id,
            orderId,
            parseFloat(discountAmount)
        );

        if (result.success) {
            res.json({
                success: true,
                discountApplied: result.discountApplied,
                message: 'Promo code applied successfully'
            });
        } else {
            res.status(400).json({
                success: false,
                error: result.error
            });
        }
    } catch (error) {
        console.error('Error applying promo code:', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to apply promo code'
        });
    }
});

/**
 * @route   GET /api/promo/available
 * @desc    Get all available promo codes for the user
 * @access  Protected
 */
router.get('/available', protect, async (req, res) => {
    try {
        const codes = await getAvailablePromoCodes(req.user.id);
        res.json({
            success: true,
            data: codes
        });
    } catch (error) {
        console.error('Error fetching available promo codes:', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch promo codes'
        });
    }
});

/**
 * @route   POST /api/promo/create
 * @desc    Create a new promo code (admin only)
 * @access  Protected + Admin
 */
router.post('/create', protect, authorize('admin'), [
    body('code').notEmpty().withMessage('Promo code is required'),
    body('type').isIn(['percentage', 'fixed', 'free_delivery']).withMessage('Invalid promo type'),
    body('value').isNumeric().withMessage('Value must be a number')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                errors: errors.array()
            });
        }

        const promoData = {
            ...req.body,
            createdById: req.user.id
        };

        const promo = await createPromoCode(promoData);
        res.status(201).json({
            success: true,
            data: promo,
            message: 'Promo code created successfully'
        });
    } catch (error) {
        console.error('Error creating promo code:', error.message);
        res.status(400).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * @route   GET /api/promo/admin/list
 * @desc    Get all promo codes (admin only)
 * @access  Protected + Admin
 */
router.get('/admin/list', protect, authorize('admin'), async (req, res) => {
    try {
        const codes = await getAllPromoCodes();
        res.json({
            success: true,
            data: codes
        });
    } catch (error) {
        console.error('Error fetching all promo codes:', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch promo codes'
        });
    }
});

/**
 * @route   DELETE /api/promo/:code
 * @desc    Deactivate a promo code (admin only)
 * @access  Protected + Admin
 */
router.delete('/:code', protect, authorize('admin'), async (req, res) => {
    try {
        const success = await deactivatePromoCode(req.params.code);
        if (success) {
            res.json({
                success: true,
                message: 'Promo code deactivated successfully'
            });
        } else {
            res.status(400).json({
                success: false,
                error: 'Failed to deactivate promo code'
            });
        }
    } catch (error) {
        console.error('Error deactivating promo code:', error.message);
        res.status(500).json({
            success: false,
            error: 'Failed to deactivate promo code'
        });
    }
});

module.exports = router;
