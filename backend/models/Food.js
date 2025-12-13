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
  food_image: {
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
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Virtual field for original price (before discount)
foodSchema.virtual('originalPrice').get(function () {
  if (this.discountPercentage > 0) {
    return this.price / (1 - this.discountPercentage / 100);
  }
  return this.price;
});

module.exports = mongoose.model('Food', foodSchema);

