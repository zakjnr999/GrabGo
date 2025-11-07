const mongoose = require('mongoose');

const socialsSchema = new mongoose.Schema({
  facebook: { type: String, default: null },
  instagram: { type: String, default: null }
}, { _id: false });

const restaurantSchema = new mongoose.Schema({
  restaurant_name: {
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
  address: {
    type: String,
    required: [true, 'Please provide address']
  },
  city: {
    type: String,
    required: [true, 'Please provide city']
  },
  owner_full_name: {
    type: String,
    required: [true, 'Please provide owner full name']
  },
  owner_contact_number: {
    type: String,
    required: [true, 'Please provide owner contact number']
  },
  business_id_number: {
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
  business_id_photo: {
    type: String,
    default: null
  },
  owner_photo: {
    type: String,
    default: null
  },
  food_type: {
    type: String,
    default: null
  },
  description: {
    type: String,
    default: null
  },
  latitude: {
    type: Number,
    default: null
  },
  longitude: {
    type: Number,
    default: null
  },
  average_delivery_time: {
    type: String,
    default: null
  },
  delivery_fee: {
    type: Number,
    default: 0
  },
  min_order: {
    type: Number,
    default: 0
  },
  opening_hours: {
    type: String,
    default: null
  },
  payment_methods: [{
    type: String
  }],
  banner_images: [{
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
  is_open: {
    type: Boolean,
    default: false
  },
  total_reviews: {
    type: Number,
    default: 0
  },
  socials: {
    type: socialsSchema,
    default: null
  }
}, {
  timestamps: true
});

// Hash password before saving
restaurantSchema.pre('save', async function(next) {
  if (!this.isModified('password')) {
    return next();
  }
  const bcrypt = require('bcryptjs');
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Compare password method
restaurantSchema.methods.matchPassword = async function(enteredPassword) {
  const bcrypt = require('bcryptjs');
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('Restaurant', restaurantSchema);

