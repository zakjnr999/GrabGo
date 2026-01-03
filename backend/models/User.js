const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: [true, 'Please provide a username'],
    trim: true,
    unique: true
  },
  email: {
    type: String,
    required: [true, 'Please provide an email'],
    unique: true,
    lowercase: true,
    match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email']
  },
  password: {
    type: String,
    required: function () {
      return !this.googleId;
    },
    minlength: 6,
    select: false
  },
  phone: {
    type: Number,
    default: null
  },
  isPhoneVerified: {
    type: Boolean,
    default: false
  },
  isEmailVerified: {
    type: Boolean,
    default: false
  },
  emailVerificationToken: {
    type: String,
    default: null
  },
  emailVerificationTokenExpires: {
    type: Date,
    default: null
  },
  emailVerificationOTP: {
    type: String,
    default: null
  },
  emailVerificationOTPExpires: {
    type: Date,
    default: null
  },
  phoneVerificationOTP: {
    type: String,
    default: null
  },
  phoneVerificationOTPExpires: {
    type: Date,
    default: null
  },
  DateOfBirth: {
    type: String,
    default: null
  },
  profilePicture: {
    type: String,
    default: null
  },
  googleId: {
    type: String,
    default: null
  },
  isAdmin: {
    type: Boolean,
    default: false
  },
  role: {
    type: String,
    enum: ['customer', 'restaurant', 'rider', 'admin'],
    default: 'customer'
  },
  isActive: {
    type: Boolean,
    default: true
  },
  lastSeenAt: {
    type: Date,
    default: null
  },
  fcmTokens: [{
    token: { type: String, required: true },
    deviceId: { type: String, default: null },
    platform: { type: String, enum: ['android', 'ios', 'web'], default: 'android' },
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now }
  }],
  notificationSettings: {
    chatMessages: { type: Boolean, default: true },
    orderUpdates: { type: Boolean, default: true },
    promoNotifications: { type: Boolean, default: true },
    commentReplies: { type: Boolean, default: true },
    commentReactions: { type: Boolean, default: true },
    referralUpdates: { type: Boolean, default: true },
    paymentUpdates: { type: Boolean, default: true },
    deliveryUpdates: { type: Boolean, default: true },
    systemUpdates: { type: Boolean, default: true },
    cartReminders: { type: Boolean, default: true },
    favoritesReminders: { type: Boolean, default: true },
    reorderSuggestions: { type: Boolean, default: true },
    reengagementReminders: { type: Boolean, default: true }
  },
  // Meal-time nudge preferences
  mealTimePreferences: {
    enabled: { type: Boolean, default: true },
    breakfast: { type: Boolean, default: true },
    lunch: { type: Boolean, default: true },
    dinner: { type: Boolean, default: true },
    maxPerWeek: { type: Number, default: 3, min: 0, max: 7 }
  },
  // Nudge tracking
  lastMealNudgeAt: { type: Date, default: null },
  mealNudgesThisWeek: { type: Number, default: 0 },
  lastFavoritesNudgeAt: { type: Date, default: null },
  favoritesNudgesThisWeek: { type: Number, default: 0 },
  lastReorderSuggestionAt: { type: Date, default: null },
  reorderSuggestionsThisWeek: { type: Number, default: 0 },
  lastReengagementNudgeAt: { type: Date, default: null },
  reengagementLevel: {
    type: String,
    enum: ['none', 'two_weeks', 'one_month', 'two_months'],
    default: 'none'
  },
  weekStartDate: { type: Date, default: null },
  lastOrderDate: { type: Date, default: null },
  // Favorites
  favorites: {
    restaurants: [{
      restaurantId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Restaurant'
      },
      addedAt: { type: Date, default: Date.now }
    }],
    groceryStores: [{
      storeId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'GroceryStore'
      },
      addedAt: { type: Date, default: Date.now }
    }],
    foodItems: [{
      itemId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Food'
      },
      addedAt: { type: Date, default: Date.now }
    }],
    groceryItems: [{
      itemId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'GroceryItem'
      },
      addedAt: { type: Date, default: Date.now }
    }]
  },
  // Promo code usage tracking
  usedPromoCodes: [{
    code: { type: String, required: true },
    usedAt: { type: Date, default: Date.now },
    orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order' },
    discountAmount: { type: Number, default: 0 }
  }],
  permissions: {
    canManageUsers: { type: Boolean, default: false },
    canManageProducts: { type: Boolean, default: false },
    canManageOrders: { type: Boolean, default: false },
    canManageContent: { type: Boolean, default: false }
  }
}, {
  timestamps: true
});

// Index for meal nudge queries
userSchema.index({
  lastOrderDate: 1,
  'mealTimePreferences.enabled': 1,
  lastMealNudgeAt: 1,
  mealNudgesThisWeek: 1
});

// Indexes for favorites queries
userSchema.index({ 'favorites.restaurants.restaurantId': 1 });
userSchema.index({ 'favorites.groceryStores.storeId': 1 });
userSchema.index({ 'favorites.foodItems.itemId': 1 });
userSchema.index({ 'favorites.groceryItems.itemId': 1 });

userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) {
    return next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

userSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('User', userSchema);

