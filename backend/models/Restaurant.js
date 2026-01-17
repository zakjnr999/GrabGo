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
      required: [true, 'Coordinates are required'],
      validate: {
        validator: function (coords) {
          return coords.length === 2 &&
            coords[0] >= -180 && coords[0] <= 180 && // Longitude
            coords[1] >= -90 && coords[1] <= 90;    // Latitude
        },
        message: 'Invalid coordinates. Longitude must be between -180 and 180, and Latitude between -90 and 90.'
      }
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
    max: 5,
    set: v => Math.round(v * 10) / 10 // Store with 1 decimal precision
  },
  ratingSum: {
    type: Number,
    default: 0
  },
  totalReviews: {
    type: Number,
    default: 0
  },
  priorityScore: {
    type: Number,
    default: 0,
    index: true
  },
  orderAcceptanceRate: {
    type: Number,
    default: 100,
    min: 0,
    max: 100
  },
  orderCancellationRate: {
    type: Number,
    default: 0,
    min: 0,
    max: 100
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
  timezone: {
    type: String,
    default: 'Africa/Accra' // Default for Ghana
  },
  utcOffset: {
    type: Number,
    default: 0 // Offset in minutes
  },
  totalOrders: {
    type: Number,
    default: 0
  },
  totalCancelledOrders: {
    type: Number,
    default: 0
  },
  totalRevenue: {
    type: Number,
    default: 0
  },
  monthlyRevenue: {
    type: Number,
    default: 0
  },
  last30DaysRevenue: {
    type: Number,
    default: 0
  },
  averageOrderValue: {
    type: Number,
    default: 0
  },
  monthlyOrders: {
    type: Number,
    default: 0
  },
  parentVendorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Restaurant',
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
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Virtuals for legacy support (snake_case and top-level location)
restaurantSchema.virtual('restaurant_name').get(function () { return this.restaurantName; });
restaurantSchema.virtual('is_open').get(function () { return this.isOpen; });
restaurantSchema.virtual('total_reviews').get(function () { return this.totalReviews; });
restaurantSchema.virtual('average_delivery_time').get(function () { return this.averageDeliveryTime; });
restaurantSchema.virtual('delivery_fee').get(function () { return this.deliveryFee; });
restaurantSchema.virtual('min_order').get(function () { return this.minOrder; });
restaurantSchema.virtual('opening_hours').get(function () { return this.openingHours; });
restaurantSchema.virtual('payment_methods').get(function () { return this.paymentMethods; });
restaurantSchema.virtual('latitude').get(function () { return this.location?.coordinates?.[1]; });
restaurantSchema.virtual('longitude').get(function () { return this.location?.coordinates?.[0]; });
restaurantSchema.virtual('address').get(function () { return this.location?.address; });
restaurantSchema.virtual('city').get(function () { return this.location?.city; });

restaurantSchema.virtual('isActive').get(function () {
  return !this.isDeleted && this.status === 'approved' && this.isAcceptingOrders;
});

// Automatic isOpen logic based on schedule
restaurantSchema.virtual('isScheduledOpen').get(function () {
  if (!this.openingHours) return false;

  const now = new Date();
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const today = days[now.getDay()];
  const schedule = this.openingHours[today];

  if (!schedule || schedule.isClosed) return false;

  const currentTime = now.getHours() * 60 + now.getMinutes();

  const [openHours, openMinutes] = schedule.open.split(':').map(Number);
  const [closeHours, closeMinutes] = schedule.close.split(':').map(Number);

  const openTime = openHours * 60 + openMinutes;
  let closeTime = closeHours * 60 + closeMinutes;

  // Handle shifts spanning past midnight
  if (closeTime < openTime) {
    closeTime += 24 * 60;
  }

  // Get current time in vendor's timezone
  // Priority: 1. utcOffset (Fastest) 2. Intl API (Accurate Fallback)
  let localNow;
  if (typeof this.utcOffset === 'number') {
    localNow = new Date(now.getTime() + this.utcOffset * 60000);
  } else {
    try {
      const formatter = new Intl.DateTimeFormat('en-US', {
        timeZone: this.timezone || 'Africa/Accra',
        hour: 'numeric',
        minute: 'numeric',
        hour12: false
      });
      const parts = formatter.formatToParts(now);
      const hour = parseInt(parts.find(p => p.type === 'hour').value);
      const minute = parseInt(parts.find(p => p.type === 'minute').value);
      localNow = new Date();
      localNow.setHours(hour, minute, 0, 0);
    } catch (err) {
      localNow = now;
    }
  }

  const currentTimeInTZ = localNow.getHours() * 60 + localNow.getMinutes();
  return currentTimeInTZ >= openTime && currentTimeInTZ <= closeTime;
});

// Soft-deletion middleware
restaurantSchema.pre(/^find/, function (next) {
  this.find({ isDeleted: { $ne: true } });
  next();
});

restaurantSchema.pre('aggregate', function (next) {
  const pipeline = this.pipeline();
  const firstStage = pipeline[0];

  if (firstStage && firstStage.$geoNear) {
    // Inject filter into $geoNear query to maintain geospatial stage requirements
    firstStage.$geoNear.query = { ...firstStage.$geoNear.query, isDeleted: { $ne: true } };
  } else {
    pipeline.unshift({ $match: { isDeleted: { $ne: true } } });
  }
  next();
});
// This part of the change seems to be a copy-paste error from another file,
// as 'groceryStoreSchema' is not defined in this file.
// I will only apply the relevant part of the instruction which is to fix the aggregate middleware.
// The provided snippet for 'groceryStoreSchema.pre('aggregate')' is not applicable here.

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

// Rating recalculation helper
restaurantSchema.methods.updateRating = async function (newScore) {
  this.ratingSum += newScore;
  this.totalReviews += 1;
  this.rating = Math.round((this.ratingSum / this.totalReviews) * 10) / 10;
  return this.save();
};

module.exports = mongoose.model('Restaurant', restaurantSchema);
