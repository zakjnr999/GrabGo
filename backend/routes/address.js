const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
    getUserAddresses,
    addUserAddress,
    updateUserAddress,
    deleteUserAddress,
    setDefaultAddress,
} = require('../services/address_service');
const { body, validationResult } = require('express-validator');

const validateAddress = [
    body('latitude').isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
    body('longitude').isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
    body('formatted_address').trim().notEmpty().withMessage('Address is required'),
    body('label').optional().isIn(['home', 'work', 'other']).withMessage('Invalid label'),
    body('custom_label').optional().trim().isLength({ max: 50 }).withMessage('Custom label too long'),
    body('building_type').optional().isIn(['house', 'apartment', 'office', 'villa', 'hostel', 'other']).withMessage('Invalid building type'),
    body('is_complete').optional().isBoolean().withMessage('is_complete must be a boolean'),
    body('is_temporary').optional().isBoolean().withMessage('is_temporary must be a boolean'),
    body('is_default').optional().isBoolean().withMessage('is_default must be a boolean'),
    (req, res, next) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ success: false, errors: errors.array() });
        }
        next();
    }
];

/**
 * @route   GET /api/addresses
 * @desc    Get all user addresses
 * @access  Private
 */
router.get('/', protect, async (req, res) => {
    try {
        const addresses = await getUserAddresses(req.user.id);
        res.json({
            success: true,
            data: addresses,
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to fetch addresses',
        });
    }
});

/**
 * @route   POST /api/addresses
 * @desc    Add a new address
 * @access  Private
 */
router.post('/', protect, validateAddress, async (req, res) => {
    try {
        const address = await addUserAddress(req.user.id, req.body);
        res.status(201).json({
            success: true,
            message: 'Address added successfully',
            data: address,
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to add address',
        });
    }
});

/**
 * @route   PATCH /api/addresses/:id
 * @desc    Update an address
 * @access  Private
 */
router.patch('/:id', protect, validateAddress, async (req, res) => {
    try {
        const address = await updateUserAddress(req.user.id, req.params.id, req.body);
        res.json({
            success: true,
            message: 'Address updated successfully',
            data: address,
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to update address',
        });
    }
});

/**
 * @route   PATCH /api/addresses/:id/default
 * @desc    Set address as default
 * @access  Private
 */
router.patch('/:id/default', protect, async (req, res) => {
    try {
        const address = await setDefaultAddress(req.user.id, req.params.id);
        res.json({
            success: true,
            message: 'Default address updated',
            data: address,
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to set default address',
        });
    }
});

/**
 * @route   DELETE /api/addresses/:id
 * @desc    Delete an address
 * @access  Private
 */
router.delete('/:id', protect, async (req, res) => {
    try {
        await deleteUserAddress(req.user.id, req.params.id);
        res.json({
            success: true,
            message: 'Address deleted successfully',
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to delete address',
        });
    }
});

module.exports = router;
