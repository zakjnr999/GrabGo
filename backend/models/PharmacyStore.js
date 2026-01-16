const mongoose = require('mongoose');

const pharmacyStoreSchema = new mongoose.Schema(
    {
        store_name: {
            type: String,
            required: [true, 'Pharmacy name is required'],
            trim: true,
        },
        logo: {
            type: String,
            required: [true, 'Pharmacy logo is required'],
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
        licenseNumber: {
            type: String,
            required: [true, 'Pharmacy license number is required'],
            unique: true,
        },
        pharmacistName: {
            type: String,
            required: [true, 'Pharmacist name is required'],
        },
        pharmacistLicense: {
            type: String,
            required: [true, 'Pharmacist license is required'],
        },
        operatingHours: {
            type: String,
            default: '24/7',
        },
        prescriptionRequired: {
            type: Boolean,
            default: false,
        },
        emergencyService: {
            type: Boolean,
            default: false,
        },
        insuranceAccepted: [{
            type: String,
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
pharmacyStoreSchema.index({ store_name: 1 });
pharmacyStoreSchema.index({ isOpen: 1 });
pharmacyStoreSchema.index({ rating: -1 });
pharmacyStoreSchema.index({ licenseNumber: 1 });

const PharmacyStore = mongoose.model('PharmacyStore', pharmacyStoreSchema);

module.exports = PharmacyStore;
