const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
    status: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Status', // Both in MongoDB
        required: true,
        index: true
    },
    user: {
        type: String, // String reference to PostgreSQL User ID
        required: true,
        index: true
    },
    text: {
        type: String,
        required: [true, 'Comment text is required'],
        trim: true,
        minlength: [1, 'Comment must be at least 1 character'],
        maxlength: [500, 'Comment cannot exceed 500 characters']
    },
    parentComment: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Comment',
        default: null,
        index: true
    }
}, {
    timestamps: true
});

// Compound index for efficient queries (get comments for a status, sorted by date)
commentSchema.index({ status: 1, createdAt: -1 });

// Index for replies
commentSchema.index({ parentComment: 1, createdAt: 1 });

// Compound index for top-level comments
commentSchema.index({ status: 1, parentComment: 1, createdAt: -1 });

// Index for user's comments
commentSchema.index({ user: 1, createdAt: -1 });

// NOTE: Auto-populate is disabled in hybrid mode because 'User' is in PostgreSQL.
// Hydration must be handled manually in the service layer.

// Static method to get comments for a status with pagination (top-level only)
commentSchema.statics.getCommentsForStatus = async function (statusId, page = 1, limit = 20) {
    const skip = (page - 1) * limit;

    const [comments, total] = await Promise.all([
        this.find({
            status: statusId,
            parentComment: null // Only top-level comments
        })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean(),
        this.countDocuments({
            status: statusId,
            parentComment: null
        })
    ]);

    // Get reply counts for each comment
    const commentIds = comments.map(c => c._id);
    const replyCounts = await this.aggregate([
        { $match: { parentComment: { $in: commentIds } } },
        { $group: { _id: '$parentComment', count: { $sum: 1 } } }
    ]);

    const replyCountMap = {};
    replyCounts.forEach(rc => {
        replyCountMap[rc._id.toString()] = rc.count;
    });

    comments.forEach(c => {
        c.replyCount = replyCountMap[c._id.toString()] || 0;
    });

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

// Static method to get replies for a comment with pagination
commentSchema.statics.getReplies = async function (commentId, page = 1, limit = 10) {
    const skip = (page - 1) * limit;

    const [replies, total] = await Promise.all([
        this.find({ parentComment: commentId })
            .sort({ createdAt: 1 }) // Oldest first for replies
            .skip(skip)
            .limit(limit)
            .lean(),
        this.countDocuments({ parentComment: commentId })
    ]);

    return {
        replies,
        pagination: {
            currentPage: page,
            totalPages: Math.ceil(total / limit),
            totalItems: total,
            itemsPerPage: limit,
            hasMore: skip + replies.length < total
        }
    };
};

// Static method to delete all comments for a status (when status is deleted)
commentSchema.statics.deleteForStatus = async function (statusId) {
    return this.deleteMany({ status: statusId });
};

// Method to check if user owns this comment
commentSchema.methods.isOwnedBy = function (userId) {
    // In hybrid setup, 'user' is the string ID
    return this.user.toString() === userId.toString();
};

module.exports = mongoose.model('Comment', commentSchema);
