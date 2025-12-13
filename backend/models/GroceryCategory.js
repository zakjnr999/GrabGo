const mongoose = require('mongoose');

const groceryCategorySchema = new mongoose.Schema(
    {
        name: {
            type: String,
            required: [true, 'Category name is required'],
            unique: true,
            trim: true,
        },
        emoji: {
            type: String,
            required: [true, 'Emoji is required'],
        },
        description: {
            type: String,
            default: '',
        },
        image: {
            type: String,
            default: '',
        },
        sortOrder: {
            type: Number,
            default: 0,
        },
        isActive: {
            type: Boolean,
            default: true,
        },
    },
    {
        timestamps: true,
    }
);

// Indexes
groceryCategorySchema.index({ sortOrder: 1 });
groceryCategorySchema.index({ isActive: 1 });

const GroceryCategory = mongoose.model('GroceryCategory', groceryCategorySchema);

module.exports = GroceryCategory;
