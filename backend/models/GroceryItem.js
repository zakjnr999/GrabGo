const mongoose = require('mongoose');

const groceryItemSchema = new mongoose.Schema(
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
            enum: ['kg', 'lbs', 'piece', 'pack', 'dozen', 'liter', 'ml', 'gram'],
        },
        category: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'GroceryCategory',
            required: [true, 'Category is required'],
        },
        store: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'GroceryStore',
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
        nutritionInfo: {
            calories: { type: Number, default: 0 },
            protein: { type: Number, default: 0 },
            carbs: { type: Number, default: 0 },
            fat: { type: Number, default: 0 },
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
            index: true, // For sorting by popularity
        },
    },
    {
        timestamps: true,
        toJSON: { virtuals: true },
        toObject: { virtuals: true },
    }
);

// Virtual for discounted price (price field stores original price)
groceryItemSchema.virtual('discountedPrice').get(function () {
    if (this.discountPercentage > 0) {
        return this.price * (1 - this.discountPercentage / 100);
    }
    return this.price;
});

// Indexes for better query performance
groceryItemSchema.index({ name: 'text', description: 'text' });
groceryItemSchema.index({ category: 1 });
groceryItemSchema.index({ store: 1 });
groceryItemSchema.index({ price: 1 });
groceryItemSchema.index({ rating: -1 });
groceryItemSchema.index({ isAvailable: 1 });
groceryItemSchema.index({ discountPercentage: -1 });
groceryItemSchema.index({ orderCount: -1 }); // For popular items query

const GroceryItem = mongoose.model('GroceryItem', groceryItemSchema);

module.exports = GroceryItem;
