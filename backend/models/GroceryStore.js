const mongoose = require('mongoose');

const groceryStoreSchema = new mongoose.Schema(
    {
        store_name: {
            type: String,
            required: [true, 'Store name is required'],
            trim: true,
        },
        logo: {
            type: String,
            required: [true, 'Store logo is required'],
        },
        description: {
            type: String,
            default: '',
        },
        address: {
            type: String,
            required: [true, 'Address is required'],
        },
        phone: {
            type: String,
            required: [true, 'Phone number is required'],
        },
        email: {
            type: String,
            required: [true, 'Email is required'],
            lowercase: true,
        },
        isOpen: {
            type: Boolean,
            default: true,
        },
        deliveryFee: {
            type: Number,
            required: [true, 'Delivery fee is required'],
            min: [0, 'Delivery fee cannot be negative'],
        },
        minOrder: {
            type: Number,
            required: [true, 'Minimum order is required'],
            min: [0, 'Minimum order cannot be negative'],
        },
        rating: {
            type: Number,
            default: 0,
            min: [0, 'Rating cannot be negative'],
            max: [5, 'Rating cannot exceed 5'],
        },
        categories: [{
            type: String,
        }],
        latitude: {
            type: Number,
            default: 0,
        },
        longitude: {
            type: Number,
            default: 0,
        },
    },
    {
        timestamps: true,
        toJSON: { virtuals: true },
        toObject: { virtuals: true },
    }
);

// Indexes for better query performance
groceryStoreSchema.index({ store_name: 1 });
groceryStoreSchema.index({ isOpen: 1 });
groceryStoreSchema.index({ rating: -1 });

const GroceryStore = mongoose.model('GroceryStore', groceryStoreSchema);

module.exports = GroceryStore;
