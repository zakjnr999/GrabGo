const express = require('express');
const { body, validationResult } = require('express-validator');
const Order = require('../models/Order');
const Transaction = require('../models/Transaction');
const RiderWallet = require('../models/RiderWallet');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

// @route   GET /api/riders/available-orders
// @desc    Get available orders for riders (not assigned)
// @access  Private/Rider
router.get('/available-orders', protect, authorize('rider', 'admin'), async (req, res) => {
  try {
    const availableOrders = await Order.find({
      rider: null,
      status: { $in: ['confirmed', 'preparing', 'ready'] }
    })
      .populate('customer', 'username email phone')
      .populate('restaurant', 'restaurant_name logo address latitude longitude')
      .sort({ createdAt: -1 })
      .limit(50);

    res.json({
      success: true,
      message: 'Available orders retrieved successfully',
      data: availableOrders
    });
  } catch (error) {
    console.error('Get available orders error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   POST /api/riders/accept-order/:orderId
// @desc    Accept an order (assign rider to order)
// @access  Private/Rider
router.post('/accept-order/:orderId', protect, authorize('rider'), async (req, res) => {
  try {
    const { orderId } = req.params;
    
    const order = await Order.findById(orderId);
    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    if (order.rider) {
      return res.status(400).json({
        success: false,
        message: 'Order already assigned to a rider'
      });
    }

    if (!['confirmed', 'preparing', 'ready'].includes(order.status)) {
      return res.status(400).json({
        success: false,
        message: 'Order is not available for pickup'
      });
    }

    order.rider = req.user._id;
    if (order.status === 'ready') {
      order.status = 'picked_up';
    }
    await order.save();

    await order.populate('customer', 'username email phone');
    await order.populate('restaurant', 'restaurant_name logo address');
    await order.populate('rider', 'username email phone');

    res.json({
      success: true,
      message: 'Order accepted successfully',
      data: order
    });
  } catch (error) {
    console.error('Accept order error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   GET /api/riders/wallet
// @desc    Get rider wallet information
// @access  Private/Rider
router.get('/wallet', protect, authorize('rider'), async (req, res) => {
  try {
    let wallet = await RiderWallet.findOne({ rider: req.user._id });
    
    if (!wallet) {
      wallet = await RiderWallet.create({ rider: req.user._id });
    } else {
      await wallet.updateBalance();
    }

    res.json({
      success: true,
      message: 'Wallet retrieved successfully',
      data: {
        balance: wallet.balance,
        totalEarnings: wallet.totalEarnings,
        totalWithdrawals: wallet.totalWithdrawals,
        pendingWithdrawals: wallet.pendingWithdrawals
      }
    });
  } catch (error) {
    console.error('Get wallet error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   GET /api/riders/earnings
// @desc    Get rider earnings (with period filter)
// @access  Private/Rider
router.get('/earnings', protect, authorize('rider'), async (req, res) => {
  try {
    const { period = 'allTime' } = req.query; // today, thisWeek, thisMonth, allTime
    
    let startDate = null;
    const now = new Date();
    
    switch (period) {
      case 'today':
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        break;
      case 'thisWeek':
        const dayOfWeek = now.getDay();
        startDate = new Date(now);
        startDate.setDate(now.getDate() - dayOfWeek);
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'thisMonth':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      default:
        startDate = null;
    }

    const query = {
      rider: req.user._id,
      type: { $in: ['delivery', 'tip', 'bonus'] },
      status: 'completed'
    };

    if (startDate) {
      query.createdAt = { $gte: startDate };
    }

    const earnings = await Transaction.find(query)
      .populate('order', 'orderNumber totalAmount')
      .sort({ createdAt: -1 });

    // Calculate totals
    const totals = await Transaction.aggregate([
      { $match: query },
      {
        $group: {
          _id: '$type',
          total: { $sum: '$amount' },
          count: { $sum: 1 }
        }
      }
    ]);

    const summary = {
      total: 0,
      delivery: 0,
      tip: 0,
      bonus: 0
    };

    totals.forEach(item => {
      summary[item._id] = item.total;
      summary.total += item.total;
    });

    res.json({
      success: true,
      message: 'Earnings retrieved successfully',
      data: {
        earnings,
        summary,
        period
      }
    });
  } catch (error) {
    console.error('Get earnings error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   GET /api/riders/transactions
// @desc    Get rider transaction history
// @access  Private/Rider
router.get('/transactions', protect, authorize('rider'), async (req, res) => {
  try {
    const { period = 'allTime', type, status } = req.query;
    
    let startDate = null;
    const now = new Date();
    
    switch (period) {
      case 'today':
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        break;
      case 'thisWeek':
        const dayOfWeek = now.getDay();
        startDate = new Date(now);
        startDate.setDate(now.getDate() - dayOfWeek);
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'thisMonth':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      default:
        startDate = null;
    }

    const query = { rider: req.user._id };
    
    if (startDate) {
      query.createdAt = { $gte: startDate };
    }
    
    if (type) {
      query.type = type;
    }
    
    if (status) {
      query.status = status;
    }

    const transactions = await Transaction.find(query)
      .populate('order', 'orderNumber totalAmount')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      message: 'Transactions retrieved successfully',
      data: transactions
    });
  } catch (error) {
    console.error('Get transactions error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   POST /api/riders/withdraw
// @desc    Request withdrawal
// @access  Private/Rider
router.post('/withdraw', protect, authorize('rider'), [
  body('amount').isFloat({ min: 1 }).withMessage('Amount must be at least 1'),
  body('withdrawalMethod').isIn(['bank_account', 'mtn_mobile_money', 'vodafone_cash']).withMessage('Invalid withdrawal method'),
  body('withdrawalAccount').notEmpty().withMessage('Withdrawal account is required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { amount, withdrawalMethod, withdrawalAccount, description } = req.body;

    // Get or create wallet
    let wallet = await RiderWallet.findOne({ rider: req.user._id });
    if (!wallet) {
      wallet = await RiderWallet.create({ rider: req.user._id });
      await wallet.updateBalance();
    } else {
      await wallet.updateBalance();
    }

    // Check if rider has sufficient balance
    if (wallet.balance < amount) {
      return res.status(400).json({
        success: false,
        message: 'Insufficient balance'
      });
    }

    // Create withdrawal transaction
    const transaction = await Transaction.create({
      rider: req.user._id,
      type: 'withdrawal',
      amount: parseFloat(amount),
      description: description || `Withdrawal to ${withdrawalMethod.replace('_', ' ')}`,
      withdrawalMethod,
      withdrawalAccount,
      status: 'pending'
    });

    // Update wallet
    await wallet.updateBalance();

    res.status(201).json({
      success: true,
      message: 'Withdrawal request submitted successfully',
      data: transaction
    });
  } catch (error) {
    console.error('Withdraw error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   PUT /api/riders/transactions/:transactionId/status
// @desc    Update transaction status (Admin only)
// @access  Private/Admin
router.put('/transactions/:transactionId/status', protect, authorize('admin'), [
  body('status').isIn(['pending', 'completed', 'failed']).withMessage('Invalid status')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { transactionId } = req.params;
    const { status } = req.body;

    const transaction = await Transaction.findById(transactionId);
    if (!transaction) {
      return res.status(404).json({
        success: false,
        message: 'Transaction not found'
      });
    }

    transaction.status = status;
    if (status === 'completed') {
      transaction.processedAt = new Date();
    }
    await transaction.save();

    // Update rider wallet
    const wallet = await RiderWallet.findOne({ rider: transaction.rider });
    if (wallet) {
      await wallet.updateBalance();
    }

    res.json({
      success: true,
      message: 'Transaction status updated successfully',
      data: transaction
    });
  } catch (error) {
    console.error('Update transaction status error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

module.exports = router;

