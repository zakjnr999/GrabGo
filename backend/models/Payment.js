const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  order: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Order',
    required: true
  },
  customer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  paymentMethod: {
    type: String,
    enum: ['cash', 'card', 'mobile_money', 'online'],
    required: true
  },
  provider: {
    type: String,
    enum: ['mtn_momo', 'vodafone_cash', 'airtel_money', 'tigo_cash', 'stripe', 'paystack'],
    required: function() {
      return this.paymentMethod === 'mobile_money' || this.paymentMethod === 'card' || this.paymentMethod === 'online';
    }
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  currency: {
    type: String,
    default: 'GHS',
    enum: ['GHS', 'USD', 'EUR']
  },
  status: {
    type: String,
    enum: ['pending', 'processing', 'successful', 'failed', 'cancelled', 'expired'],
    default: 'pending'
  },
  referenceId: {
    type: String,
    required: true,
    unique: true
  },
  externalReferenceId: {
    type: String, // MTN MOMO reference ID
    default: null
  },
  financialTransactionId: {
    type: String, // MTN MOMO financial transaction ID
    default: null
  },
  phoneNumber: {
    type: String,
    required: function() {
      return this.paymentMethod === 'mobile_money';
    }
  },
  payerMessage: {
    type: String,
    default: null
  },
  payeeNote: {
    type: String,
    default: null
  },
  errorMessage: {
    type: String,
    default: null
  },
  errorCode: {
    type: String,
    default: null
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  initiatedAt: {
    type: Date,
    default: Date.now
  },
  completedAt: {
    type: Date,
    default: null
  },
  expiredAt: {
    type: Date,
    default: function() {
      // Set expiration to 5 minutes from creation for mobile money payments
      if (this.paymentMethod === 'mobile_money') {
        return new Date(Date.now() + 5 * 60 * 1000);
      }
      return null;
    }
  }
}, {
  timestamps: true
});

// Index for faster queries
paymentSchema.index({ order: 1 });
paymentSchema.index({ customer: 1 });
paymentSchema.index({ referenceId: 1 });
paymentSchema.index({ externalReferenceId: 1 });
paymentSchema.index({ status: 1 });

// Pre-save middleware to generate reference ID
paymentSchema.pre('save', function(next) {
  if (!this.referenceId) {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 10000);
    this.referenceId = `PAY-${timestamp}-${random}`;
  }
  next();
});

// Method to check if payment has expired
paymentSchema.methods.isExpired = function() {
  if (!this.expiredAt) return false;
  return new Date() > this.expiredAt;
};

// Method to mark payment as completed
paymentSchema.methods.markAsCompleted = function(financialTransactionId = null) {
  this.status = 'successful';
  this.completedAt = new Date();
  if (financialTransactionId) {
    this.financialTransactionId = financialTransactionId;
  }
  return this.save();
};

// Method to mark payment as failed
paymentSchema.methods.markAsFailed = function(errorMessage = null, errorCode = null) {
  this.status = 'failed';
  this.errorMessage = errorMessage;
  this.errorCode = errorCode;
  return this.save();
};

module.exports = mongoose.model('Payment', paymentSchema);