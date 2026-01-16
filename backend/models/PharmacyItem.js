const mongoose = require('mongoose');

const pharmacyItemSchema = new mongoose.Schema(
    {
        name: {
            type: String,
            required: [true, 'Item name is required'],
            trim: true,
        },
        description: {
            type: String,
            default: '',
        },
        image: {
            type: String,
            required: [true, 'Image is required'],
        },
        price: {
            type: Number,
            required: [true, 'Price is required'],
            min: [0, 'Price cannot be negative'],
        },
        unit: {
            type: String,
            required: [true, 'Unit is required'],
            enum: ['piece', 'pack', 'bottle', 'box', 'tube', 'strip', 'ml', 'gram', 'can'],
        },
        category: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'PharmacyCategory',
            required: [true, 'Category is required'],
        },
        store: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'PharmacyStore',
            required: [true, 'Store is required'],
        },
        brand: {
            type: String,
            default: '',
        },
        stock: {
            type: Number,
            default: 0,
            min: [0, 'Stock cannot be negative'],
        },
        isAvailable: {
            type: Boolean,
            default: true,
        },
        requiresPrescription: {
            type: Boolean,
            default: false,
        },
        discountPercentage: {
            type: Number,
            default: 0,
            min: [0, 'Discount cannot be negative'],
            max: [100, 'Discount cannot exceed 100%'],
        },
        discountEndDate: {
            type: Date,
            default: null,
        },
        expiryDate: {
            type: Date,
            default: null,
        },
        tags: [{
            type: String,
        }],
        rating: {
            type: Number,
            default: 0,
            min: [0, 'Rating cannot be negative'],
            max: [5, 'Rating cannot exceed 5'],
        },
        reviewCount: {
            type: Number,
            default: 0,
            min: [0, 'Review count cannot be negative'],
        },
        orderCount: {
            type: Number,
            default: 0,
            min: [0, 'Order count cannot be negative'],
            index: true,
        },
    },
    {
        timestamps: true,
        toJSON: { virtuals: true },
        toObject: { virtuals: true },
    }
);

// Virtual for discounted price
pharmacyItemSchema.virtual('discountedPrice').get(function () {
    if (this.discountPercentage > 0) {
        return this.price * (1 - this.discountPercentage / 100);
    }
    return this.price;
});

// Indexes for better query performance
pharmacyItemSchema.index({ name: 'text', description: 'text' });
pharmacyItemSchema.index({ category: 1 });
pharmacyItemSchema.index({ store: 1 });
pharmacyItemSchema.index({ price: 1 });
pharmacyItemSchema.index({ rating: -1 });
pharmacyItemSchema.index({ isAvailable: 1 });
pharmacyItemSchema.index({ discountPercentage: -1 });
pharmacyItemSchema.index({ orderCount: -1 });

const PharmacyItem = mongoose.model('PharmacyItem', pharmacyItemSchema);

module.exports = PharmacyItem;
