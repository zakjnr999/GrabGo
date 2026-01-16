const mongoose = require('mongoose');

const pharmacyCategorySchema = new mongoose.Schema(
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
pharmacyCategorySchema.index({ sortOrder: 1 });
pharmacyCategorySchema.index({ isActive: 1 });

const PharmacyCategory = mongoose.model('PharmacyCategory', pharmacyCategorySchema);

module.exports = PharmacyCategory;
