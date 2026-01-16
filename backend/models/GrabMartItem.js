const mongoose = require('mongoose');

const grabMartItemSchema = new mongoose.Schema(
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
            enum: ['piece', 'pack', 'bottle', 'can', 'box', 'kg', 'liter', 'ml', 'gram'],
        },
        category: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'GrabMartCategory',
            required: [true, 'Category is required'],
        },
        store: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'GrabMartStore',
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
grabMartItemSchema.virtual('discountedPrice').get(function () {
    if (this.discountPercentage > 0) {
        return this.price * (1 - this.discountPercentage / 100);
    }
    return this.price;
});

// Indexes for better query performance
grabMartItemSchema.index({ name: 'text', description: 'text' });
grabMartItemSchema.index({ category: 1 });
grabMartItemSchema.index({ store: 1 });
grabMartItemSchema.index({ price: 1 });
grabMartItemSchema.index({ rating: -1 });
grabMartItemSchema.index({ isAvailable: 1 });
grabMartItemSchema.index({ discountPercentage: -1 });
grabMartItemSchema.index({ orderCount: -1 });

const GrabMartItem = mongoose.model('GrabMartItem', grabMartItemSchema);

module.exports = GrabMartItem;
