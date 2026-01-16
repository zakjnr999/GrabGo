const mongoose = require('mongoose');

const grabMartCategorySchema = new mongoose.Schema(
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
grabMartCategorySchema.index({ sortOrder: 1 });
grabMartCategorySchema.index({ isActive: 1 });

const GrabMartCategory = mongoose.model('GrabMartCategory', grabMartCategorySchema);

module.exports = GrabMartCategory;
