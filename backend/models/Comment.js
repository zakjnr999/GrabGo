const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
    status: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Status',
        required: true,
        index: true
    },
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    text: {
        type: String,
        required: [true, 'Comment text is required'],
        trim: true,
        minlength: [1, 'Comment must be at least 1 character'],
        maxlength: [500, 'Comment cannot exceed 500 characters']
    }
}, {
    timestamps: true
});

// Compound index for efficient queries (get comments for a status, sorted by date)
commentSchema.index({ status: 1, createdAt: -1 });

// Index for user's comments
commentSchema.index({ user: 1, createdAt: -1 });

// Auto-populate user details when querying
commentSchema.pre(/^find/, function (next) {
    this.populate({
        path: 'user',
        select: 'name email profileImage'
    });
    next();
});

// Static method to get comments for a status with pagination
commentSchema.statics.getCommentsForStatus = async function (statusId, page = 1, limit = 20) {
    const skip = (page - 1) * limit;

    const [comments, total] = await Promise.all([
        this.find({ status: statusId })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean(),
        this.countDocuments({ status: statusId })
    ]);

    return {
        comments,
        pagination: {
            currentPage: page,
            totalPages: Math.ceil(total / limit),
            totalItems: total,
            itemsPerPage: limit,
            hasMore: skip + comments.length < total
        }
    };
};

// Static method to delete all comments for a status (when status is deleted)
commentSchema.statics.deleteForStatus = async function (statusId) {
    return this.deleteMany({ status: statusId });
};

// Method to check if user owns this comment
commentSchema.methods.isOwnedBy = function (userId) {
    return this.user._id.toString() === userId.toString();
};

module.exports = mongoose.model('Comment', commentSchema);
