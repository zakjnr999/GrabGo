const mongoose = require('mongoose');

const reactionSchema = new mongoose.Schema({
    comment: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Comment', // Both in MongoDB
        required: true,
        index: true
    },
    user: {
        type: String, // String reference to PostgreSQL User ID
        required: true,
        index: true
    },
    type: {
        type: String,
        enum: ['like', 'love', 'haha', 'wow', 'sad', 'angry'],
        required: true
    }
}, {
    timestamps: true
});

// Compound unique index: one reaction per user per comment
reactionSchema.index({ comment: 1, user: 1 }, { unique: true });

// Index for aggregation queries
reactionSchema.index({ comment: 1, type: 1 });

// Static method to get reaction summary for a comment
reactionSchema.statics.getSummary = async function (commentId, userId = null) {
    const reactions = await this.aggregate([
        { $match: { comment: new mongoose.Types.ObjectId(commentId) } },
        { $group: { _id: '$type', count: { $sum: 1 } } }
    ]);

    const summary = {
        like: 0,
        love: 0,
        haha: 0,
        wow: 0,
        sad: 0,
        angry: 0,
        total: 0,
        userReaction: null
    };

    reactions.forEach(r => {
        summary[r._id] = r.count;
        summary.total += r.count;
    });

    if (userId) {
        const userReaction = await this.findOne({
            comment: commentId,
            user: userId
        });
        summary.userReaction = userReaction?.type || null;
    }

    return summary;
};

// Static method to toggle reaction
reactionSchema.statics.toggle = async function (commentId, userId, type) {
    const existing = await this.findOne({ comment: commentId, user: userId });

    if (existing) {
        if (existing.type === type) {
            // Remove reaction
            await existing.deleteOne();
            return { action: 'removed', type: null };
        } else {
            // Change reaction
            existing.type = type;
            await existing.save();
            return { action: 'changed', type };
        }
    } else {
        // Add new reaction
        await this.create({ comment: commentId, user: userId, type });
        return { action: 'added', type };
    }
};

module.exports = mongoose.model('Reaction', reactionSchema);
