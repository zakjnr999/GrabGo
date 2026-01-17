const mongoose = require('mongoose');

const foodSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Please provide food name'],
    trim: true
  },
  description: {
    type: String,
    default: null
  },
  price: {
    type: Number,
    required: [true, 'Please provide price'],
    min: 0
  },
  foodImage: {
    type: String,
    default: null
  },
  category: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Category',
    required: [true, 'Please provide category']
  },
  restaurant: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Restaurant',
    required: [true, 'Please provide restaurant']
  },
  isAvailable: {
    type: Boolean,
    default: true
  },
  ingredients: [{
    type: String
  }],
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
  discountPercentage: {
    type: Number,
    default: 0,
    min: 0,
    max: 100,
    validate: {
      validator: Number.isInteger,
      message: 'Discount percentage must be an integer'
    }
  },
  discountEndDate: {
    type: Date,
    default: null
  },
  orderCount: {
    type: Number,
    default: 0,
    min: [0, 'Order count cannot be negative'],
    index: true // For sorting by popularity
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Virtual fields for legacy support
foodSchema.virtual('food_image').get(function () {
  return this.foodImage;
});

foodSchema.virtual('image').get(function () {
  return this.foodImage;
});

// Virtual field for original price (before discount)
foodSchema.virtual('originalPrice').get(function () {
  if (this.discountPercentage > 0) {
    return this.price / (1 - this.discountPercentage / 100);
  }
  return this.price;
});

// Index for popular items query
foodSchema.index({ orderCount: -1, rating: -1 });

module.exports = mongoose.model('Food', foodSchema);

