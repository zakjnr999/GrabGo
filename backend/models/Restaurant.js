const mongoose = require('mongoose');

const dayScheduleSchema = new mongoose.Schema({
  open: { type: String, default: '09:00' },
  close: { type: String, default: '21:00' },
  isClosed: { type: Boolean, default: false }
}, { _id: false });

const openingHoursSchema = new mongoose.Schema({
  monday: { type: dayScheduleSchema, default: () => ({}) },
  tuesday: { type: dayScheduleSchema, default: () => ({}) },
  wednesday: { type: dayScheduleSchema, default: () => ({}) },
  thursday: { type: dayScheduleSchema, default: () => ({}) },
  friday: { type: dayScheduleSchema, default: () => ({}) },
  saturday: { type: dayScheduleSchema, default: () => ({}) },
  sunday: { type: dayScheduleSchema, default: () => ({}) }
}, { _id: false });

const socialsSchema = new mongoose.Schema({
  facebook: { type: String, default: null },
  instagram: { type: String, default: null },
  twitter: { type: String, default: null },
  website: { type: String, default: null }
}, { _id: false });

const restaurantSchema = new mongoose.Schema({
  restaurantName: {
    type: String,
    required: [true, 'Please provide restaurant name'],
    trim: true
  },
  email: {
    type: String,
    required: [true, 'Please provide email'],
    unique: true,
    lowercase: true
  },
  phone: {
    type: String,
    required: [true, 'Please provide phone number']
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: [true, 'Coordinates are required']
    },
    address: {
      type: String,
      required: [true, 'Please provide address']
    },
    city: {
      type: String,
      required: [true, 'Please provide city']
    },
    area: {
      type: String,
      required: [true, 'Please provide area/neighborhood']
    }
  },
  ownerFullName: {
    type: String,
    required: [true, 'Please provide owner full name']
  },
  ownerContactNumber: {
    type: String,
    required: [true, 'Please provide owner contact number']
  },
  businessIdNumber: {
    type: String,
    required: [true, 'Please provide business ID number'],
    unique: true
  },
  password: {
    type: String,
    required: [true, 'Please provide password'],
    minlength: 6,
    select: false
  },
  logo: {
    type: String,
    default: null
  },
  businessIdPhoto: {
    type: String,
    default: null
  },
  ownerPhoto: {
    type: String,
    default: null
  },
  foodType: {
    type: String,
    default: null
  },
  description: {
    type: String,
    default: null
  },
  averageDeliveryTime: {
    type: Number, // In minutes
    default: 30
  },
  averagePreparationTime: {
    type: Number, // In minutes
    default: 15,
    min: [0, 'Preparation time cannot be negative']
  },
  deliveryFee: {
    type: Number,
    default: 0
  },
  minOrder: {
    type: Number,
    default: 0
  },
  openingHours: {
    type: openingHoursSchema,
    default: () => ({})
  },
  paymentMethods: [{
    type: String,
    enum: ['cash', 'card', 'mobile_money']
  }],
  bannerImages: [{
    type: String
  }],
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'suspended'],
    default: 'pending'
  },
  rating: {
    type: Number,
    default: 0,
    min: 0,
    max: 5
  },
  totalReviews: {
    type: Number,
    default: 0
  },
  isOpen: {
    type: Boolean,
    default: false
  },
  isAcceptingOrders: {
    type: Boolean,
    default: true
  },
  deliveryRadius: {
    type: Number, // In km
    default: 5,
    min: [0, 'Delivery radius cannot be negative']
  },
  features: [{
    type: String,
    enum: ['wifi', 'parking', 'wheelchair_accessible', 'outdoor_seating',
      'takeaway', 'dine_in', 'halal', 'vegan_options', 'alcohol_served',
      'live_music', 'air_conditioned', 'pet_friendly']
  }],
  tags: [{
    type: String
  }],
  featured: {
    type: Boolean,
    default: false
  },
  featuredUntil: {
    type: Date,
    default: null
  },
  isVerified: {
    type: Boolean,
    default: false
  },
  verifiedAt: {
    type: Date,
    default: null
  },
  whatsappNumber: {
    type: String,
    default: null
  },
  isGrabGoExclusive: {
    type: Boolean,
    default: false
  },
  isGrabGoExclusiveUntil: {
    type: Date,
    default: null
  },
  socials: {
    type: socialsSchema,
    default: () => ({})
  },
  vendorType: {
    type: String,
    enum: ['restaurant', 'grocery', 'pharmacy', 'grabmart'],
    default: 'restaurant'
  },
  isDeleted: {
    type: Boolean,
    default: false
  },
  lastOnlineAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Production Indexes
restaurantSchema.index({ "location.coordinates": "2dsphere" });
restaurantSchema.index({ status: 1, isOpen: 1, isDeleted: 1, rating: -1 });
restaurantSchema.index({ vendorType: 1, status: 1, isDeleted: 1 });
restaurantSchema.index({ "location.city": 1, "location.area": 1 });
restaurantSchema.index({ email: 1 });
restaurantSchema.index({ businessIdNumber: 1 });

restaurantSchema.pre('save', async function (next) {
  if (!this.isModified('password')) {
    return next();
  }
  const bcrypt = require('bcryptjs');
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

restaurantSchema.methods.matchPassword = async function (enteredPassword) {
  const bcrypt = require('bcryptjs');
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('Restaurant', restaurantSchema);
