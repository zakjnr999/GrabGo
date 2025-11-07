const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  rider: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  order: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Order',
    default: null
  },
  type: {
    type: String,
    enum: ['delivery', 'tip', 'bonus', 'withdrawal', 'penalty'],
    required: true
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  description: {
    type: String,
    required: true
  },
  withdrawalMethod: {
    type: String,
    enum: ['bank_account', 'mtn_mobile_money', 'vodafone_cash'],
    default: null
  },
  withdrawalAccount: {
    type: String,
    default: null
  },
  status: {
    type: String,
    enum: ['pending', 'completed', 'failed'],
    default: 'pending'
  },
  processedAt: {
    type: Date,
    default: null
  }
}, {
  timestamps: true
});

transactionSchema.index({ rider: 1, createdAt: -1 });
transactionSchema.index({ order: 1 });

module.exports = mongoose.model('Transaction', transactionSchema);

