const prisma = require('../config/prisma');
const Status = require('../models/Status');
const Comment = require('../models/Comment');
const Reaction = require('../models/Reaction');

/**
 * Status (Stories) Service
 * 
 * Handles business logic for stories, views, likes, and comments
 * Using Hybrid Architecture: Status/Social data in MongoDB, User/Entity data in PostgreSQL
 */

/**
 * Record a single view with duration
 */
const recordView = async (statusId, userId, duration = 0) => {
    try {
        const status = await Status.findById(statusId);
        if (!status) throw new Error('Status not found');

        await status.recordView(userId.toString(), duration);
        return status;
    } catch (error) {
        console.error('❌ Error recording view in MongoDB:', error.message);
        throw error;
    }
};

/**
 * Record batch views
 */
const recordBatchViews = async (userId, views) => {
    try {
        // Use the static method restored in the Status model
        return await Status.recordBatchViews(userId.toString(), views);
    } catch (error) {
        console.error('❌ Error recording batch views in MongoDB:', error.message);
        return views.map(v => ({ statusId: v.statusId, success: false, reason: error.message }));
    }
};

/**
 * Toggle like
 */
const toggleLike = async (statusId, userId) => {
    try {
        const status = await Status.findById(statusId);
        if (!status) throw new Error('Status not found');

        return await status.toggleLike(userId.toString());
    } catch (error) {
        console.error('❌ Error toggling like in MongoDB:', error.message);
        throw error;
    }
};

/**
 * Get comments for a status with pagination (Hydrated from PostgreSQL)
 */
const getCommentsForStatus = async (statusId, page = 1, limit = 20) => {
    try {
        // Use static method from Comment model
        const result = await Comment.getCommentsForStatus(statusId, page, limit);

        // Manual Hydration: Pull user details from PostgreSQL for each comment
        const userIds = [...new Set(result.comments.map(c => c.user))];
        const users = await prisma.user.findMany({
            where: { id: { in: userIds } },
            select: { id: true, username: true, email: true, profilePicture: true }
        });

        const userMap = users.reduce((acc, user) => {
            acc[user.id] = {
                ...user,
                name: user.username,
                profileImage: user.profilePicture
            };
            return acc;
        }, {});

        result.comments = result.comments.map(c => ({
            ...c,
            user: userMap[c.user] || { id: c.user, name: 'Deleted User' }
        }));

        return result;
    } catch (error) {
        console.error('❌ Error fetching comments from MongoDB:', error.message);
        throw error;
    }
};

/**
 * Get replies for a comment with pagination (Hydrated from PostgreSQL)
 */
const getReplies = async (commentId, page = 1, limit = 10) => {
    try {
        const result = await Comment.getReplies(commentId, page, limit);

        // Manual Hydration
        const userIds = [...new Set(result.replies.map(r => r.user))];
        const users = await prisma.user.findMany({
            where: { id: { in: userIds } },
            select: { id: true, username: true, email: true, profilePicture: true }
        });

        const userMap = users.reduce((acc, user) => {
            acc[user.id] = {
                ...user,
                name: user.username,
                profileImage: user.profilePicture
            };
            return acc;
        }, {});

        result.replies = result.replies.map(r => ({
            ...r,
            user: userMap[r.user] || { id: r.user, name: 'Deleted User' }
        }));

        return result;
    } catch (error) {
        console.error('❌ Error fetching replies from MongoDB:', error.message);
        throw error;
    }
};

/**
 * Toggle reaction on a comment
 */
const toggleReaction = async (commentId, userId, type) => {
    try {
        // Use static method from Reaction model
        return await Reaction.toggleReaction(commentId, userId.toString(), type);
    } catch (error) {
        console.error('❌ Error toggling reaction in MongoDB:', error.message);
        throw error;
    }
};

/**
 * Get reaction summary for a comment
 */
const getReactionSummary = async (commentId, userId = null) => {
    try {
        // Use static method from Reaction model
        return await Reaction.getReactionSummary(commentId, userId ? userId.toString() : null);
    } catch (error) {
        console.error('❌ Error getting reaction summary from MongoDB:', error.message);
        return { total: 0, userReaction: null };
    }
};

/**
 * Cleanup expired statuses and their images
 */
const cleanupExpired = async (cloudinary = null) => {
    try {
        // Use static method from Status model
        return await Status.cleanupExpired(cloudinary);
    } catch (error) {
        console.error('❌ Error cleaning up expired statuses in MongoDB:', error.message);
        throw error;
    }
};

/**
 * Engagement score calculation (Exposed for external use if needed, but model handles it internally)
 */
const calculateEngagementScore = (status) => {
    const durationFactor = status.avgViewDuration > 0 ? (status.avgViewDuration / 1000) / 10 : 0;
    return status.viewCount + (status.likeCount * 2) + durationFactor;
};

module.exports = {
    recordView,
    recordBatchViews,
    toggleLike,
    getCommentsForStatus,
    getReplies,
    toggleReaction,
    getReactionSummary,
    cleanupExpired,
    calculateEngagementScore
};
