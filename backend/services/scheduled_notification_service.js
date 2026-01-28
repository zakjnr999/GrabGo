const prisma = require('../config/prisma');
const { createNotification } = require('./notification_service');

/**
 * Scheduled Notification Service
 * 
 * Manages scheduling and delivery of delayed notifications
 */

/**
 * Create a scheduled notification
 * @param {Object} data - Notification data
 * @returns {Promise<Object>} Created scheduled notification
 */
const createScheduledNotification = async (data) => {
    try {
        const {
            userId,
            scheduledAt,
            type,
            title,
            message,
            notificationData = {}
        } = data;

        const scheduledDate = new Date(scheduledAt);
        if (isNaN(scheduledDate.getTime())) {
            throw new Error('Invalid date format for scheduledAt');
        }

        // Create scheduled notification
        const scheduledNotification = await prisma.scheduledNotification.create({
            data: {
                userId,
                scheduledAt: scheduledDate,
                type,
                title,
                message,
                data: notificationData,
                sent: false
            }
        });

        console.log(`📅 Scheduled notification created: ${scheduledNotification.id} for ${scheduledDate}`);
        return scheduledNotification;
    } catch (error) {
        console.error('Error creating scheduled notification:', error.message);
        throw error;
    }
};

/**
 * Process scheduled notifications that are due
 */
const processScheduledNotifications = async (io = null) => {
    try {
        const now = new Date();

        // Find due notifications that haven't been sent
        const dueNotifications = await prisma.scheduledNotification.findMany({
            where: {
                sent: false,
                scheduledAt: { lte: now }
            },
            orderBy: { scheduledAt: 'asc' },
            take: 50
        });

        if (dueNotifications.length === 0) {
            return { processed: 0, sent: 0, failed: 0 };
        }

        console.log(`📬 Processing ${dueNotifications.length} scheduled notifications...`);

        let sentCount = 0;
        let failedCount = 0;

        for (const scheduledNotif of dueNotifications) {
            try {
                // Send the notification
                const result = await createNotification(
                    scheduledNotif.userId,
                    scheduledNotif.type,
                    scheduledNotif.title,
                    scheduledNotif.message,
                    scheduledNotif.data || {},
                    io
                );

                if (result) {
                    // Mark as sent
                    await prisma.scheduledNotification.update({
                        where: { id: scheduledNotif.id },
                        data: {
                            sent: true,
                            sentAt: new Date()
                        }
                    });
                    sentCount++;
                } else {
                    // Notification was rate-limited or failed validation
                    // Reschedule for 5 minutes later (up to 3 retries)
                    const currentData = scheduledNotif.data || {};
                    const retryCount = (currentData.retryCount || 0) + 1;

                    if (retryCount <= 3) {
                        await prisma.scheduledNotification.update({
                            where: { id: scheduledNotif.id },
                            data: {
                                scheduledAt: new Date(Date.now() + 5 * 60 * 1000), // 5 min later
                                data: { ...currentData, retryCount }
                            }
                        });
                        console.log(`⏰ Rescheduled notification ${scheduledNotif.id} (retry ${retryCount}/3)`);
                    } else {
                        // Max retries reached, mark as failed
                        await prisma.scheduledNotification.update({
                            where: { id: scheduledNotif.id },
                            data: {
                                sent: true, // Mark as "processed"
                                data: { ...currentData, failed: true, failureReason: 'max_retries_exceeded' }
                            }
                        });
                        console.error(`❌ Notification ${scheduledNotif.id} failed after 3 retries`);
                    }
                    failedCount++;
                }
            } catch (error) {
                console.error(`❌ Failed to send scheduled notification ${scheduledNotif.id}:`, error.message);
                
                // Track the error in the notification data
                try {
                    const currentData = scheduledNotif.data || {};
                    const retryCount = (currentData.retryCount || 0) + 1;

                    if (retryCount <= 3) {
                        await prisma.scheduledNotification.update({
                            where: { id: scheduledNotif.id },
                            data: {
                                scheduledAt: new Date(Date.now() + 5 * 60 * 1000),
                                data: { ...currentData, retryCount, lastError: error.message }
                            }
                        });
                    } else {
                        await prisma.scheduledNotification.update({
                            where: { id: scheduledNotif.id },
                            data: {
                                sent: true,
                                data: { ...currentData, failed: true, failureReason: error.message }
                            }
                        });
                    }
                } catch (updateError) {
                    console.error(`❌ Failed to update notification status:`, updateError.message);
                }
                
                failedCount++;
            }
        }

        return { processed: dueNotifications.length, sent: sentCount, failed: failedCount };
    } catch (error) {
        console.error('Error processing scheduled notifications:', error.message);
        throw error;
    }
};

/**
 * Cancel a scheduled notification
 */
const cancelScheduledNotification = async (notificationId, userId = null) => {
    try {
        const where = { id: notificationId, sent: false };
        if (userId) where.userId = userId;

        const updated = await prisma.scheduledNotification.deleteMany({
            where
        });

        return updated.count > 0;
    } catch (error) {
        console.error('Error cancelling scheduled notification:', error.message);
        return false;
    }
};

/**
 * Get scheduled notifications with filters
 */
const getScheduledNotifications = async (filters = {}, limit = 50, skip = 0) => {
    try {
        const where = {};
        if (filters.sent !== undefined) where.sent = filters.sent === 'true';
        if (filters.userId) where.userId = filters.userId;

        return await prisma.scheduledNotification.findMany({
            where,
            orderBy: { scheduledAt: 'desc' },
            skip,
            take: limit
        });
    } catch (error) {
        console.error('Error getting scheduled notifications:', error.message);
        return [];
    }
};

module.exports = {
    createScheduledNotification,
    processScheduledNotifications,
    cancelScheduledNotification,
    getScheduledNotifications
};
