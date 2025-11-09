const mongoose = require('mongoose');

const riderSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  // Vehicle Information
  vehicleType: {
    type: String,
    enum: ['motorcycle', 'bicycle', 'car', 'scooter'],
    default: null
  },
  licensePlateNumber: {
    type: String,
    default: null
  },
  vehicleBrand: {
    type: String,
    default: null
  },
  vehicleModel: {
    type: String,
    default: null
  },
  vehicleImage: {
    type: String, // URL to uploaded image
    default: null
  },
  // Identity Verification
  nationalIdType: {
    type: String,
    enum: ['national_id', 'passport', 'drivers_license'],
    default: null
  },
  nationalIdNumber: {
    type: String,
    default: null
  },
  idFrontImage: {
    type: String, // URL to uploaded image
    default: null
  },
  idBackImage: {
    type: String, // URL to uploaded image
    default: null
  },
  selfiePhoto: {
    type: String, // URL to uploaded image
    default: null
  },
  // Payment Information
  paymentMethod: {
    type: String,
    enum: ['bank_account', 'mobile_money'],
    default: null
  },
  bankName: {
    type: String,
    default: null
  },
  accountNumber: {
    type: String,
    default: null
  },
  accountHolderName: {
    type: String,
    default: null
  },
  mobileMoneyProvider: {
    type: String,
    enum: ['mtn', 'vodafone', 'airtel', 'tigo'],
    default: null
  },
  mobileMoneyNumber: {
    type: String,
    default: null
  },
  // Verification Status
  verificationStatus: {
    type: String,
    enum: ['pending', 'under_review', 'approved', 'rejected'],
    default: 'pending'
  },
  rejectionReason: {
    type: String,
    default: null
  },
  verifiedAt: {
    type: Date,
    default: null
  },
  // Agreements
  agreedToTerms: {
    type: Boolean,
    default: false
  },
  agreedToLocationAccess: {
    type: Boolean,
    default: false
  },
  agreedToAccuracy: {
    type: Boolean,
    default: false
  },
  // Additional Info
  notes: {
    type: String,
    default: null
  }
}, {
  timestamps: true
});

// Index for faster queries
riderSchema.index({ user: 1 });
riderSchema.index({ verificationStatus: 1 });

module.exports = mongoose.model('Rider', riderSchema);

