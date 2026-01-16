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
        owner_full_name: {
            type: String,
            default: null,
        },
        owner_contact_number: {
            type: String,
            default: null,
        },
        business_id_number: {
            type: String,
            default: null,
        },
        password: {
            type: String,
            minlength: 6,
            select: false,
        },
        business_id_photo: {
            type: String,
            default: null,
        },
        owner_photo: {
            type: String,
            default: null,
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
        city: {
            type: String,
            default: null,
        },
        average_delivery_time: {
            type: String,
            default: null,
        },
        payment_methods: [{
            type: String,
        }],
        banner_images: [{
            type: String,
        }],
        status: {
            type: String,
            enum: ['pending', 'approved', 'rejected', 'suspended'],
            default: 'approved',
        },
        // High-Priority Production Fields
        averagePreparationTime: {
            type: Number,
            default: null,
            min: [0, 'Preparation time cannot be negative'],
        },
        isAcceptingOrders: {
            type: Boolean,
            default: true,
        },
        deliveryRadius: {
            type: Number,
            default: 5,
            min: [0, 'Delivery radius cannot be negative'],
        },
        features: [{
            type: String,
            enum: ['wifi', 'parking', 'wheelchair_accessible', 'outdoor_seating',
                'takeaway', 'dine_in', 'halal', 'vegan_options', 'alcohol_served',
                'live_music', 'air_conditioned', 'pet_friendly'],
        }],
        tags: [{
            type: String,
        }],
        featured: {
            type: Boolean,
            default: false,
        },
        featuredUntil: {
            type: Date,
            default: null,
        },
        isVerified: {
            type: Boolean,
            default: false,
        },
        verifiedAt: {
            type: Date,
            default: null,
        },
        whatsappNumber: {
            type: String,
            default: null,
        },
        isGrabGoExclusive: {
            type: Boolean,
            default: false,
        },
        socials: {
            facebook: { type: String, default: null },
            instagram: { type: String, default: null },
        },
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
