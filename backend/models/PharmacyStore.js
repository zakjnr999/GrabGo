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
