const mongoose = require('mongoose');

const grabMartStoreSchema = new mongoose.Schema(
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
        totalReviews: {
            type: Number,
            default: 0,
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
        operatingHours: {
            type: String,
            default: '24/7',
        },
        is24Hours: {
            type: Boolean,
            default: false,
        },
        hasParking: {
            type: Boolean,
            default: false,
        },
        acceptsCash: {
            type: Boolean,
            default: true,
        },
        acceptsCard: {
            type: Boolean,
            default: true,
        },
        acceptsMobileMoney: {
            type: Boolean,
            default: true,
        },
        services: [{
            type: String,
            enum: ['ATM', 'Bill Payment', 'Mobile Top-up', 'Money Transfer', 'Photocopying', 'Printing'],
        }],
        productTypes: [{
            type: String,
            enum: ['Snacks', 'Beverages', 'Personal Care', 'Household', 'Electronics', 'Stationery', 'Tobacco'],
        }],
    },
    {
        timestamps: true,
        toJSON: { virtuals: true },
        toObject: { virtuals: true },
    }
);

// Indexes for better query performance
grabMartStoreSchema.index({ store_name: 1 });
grabMartStoreSchema.index({ isOpen: 1 });
grabMartStoreSchema.index({ rating: -1 });
grabMartStoreSchema.index({ is24Hours: 1 });

const GrabMartStore = mongoose.model('GrabMartStore', grabMartStoreSchema);

module.exports = GrabMartStore;
