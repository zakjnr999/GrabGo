# Scheduled Notifications - Testing Guide

## Overview

The scheduled notifications feature allows you to schedule notifications to be sent at specific future times. This guide explains how to test the feature using the provided scripts.

## Prerequisites

1. MongoDB running
2. Backend server running (`npm run dev`)
3. At least one user in the database

## Test Scripts

### 1. Run All Tests

Tests the complete functionality with 5 different scenarios:

```bash
node scripts/test_scheduled_notifications.js
```

**What it does:**
- ✅ Creates notification for 30 seconds from now
- ✅ Creates notification for 2 minutes from now
- ✅ Creates notification for tomorrow at 9 AM
- ✅ Creates recurring daily notification
- ✅ Tests validation (rejects past dates)

**Expected output:**
- All 5 tests should complete successfully
- Check your server logs to see notifications being sent
- The 30-second and 2-minute notifications should send shortly

---

### 2. Create Custom Notification

Create a single scheduled notification with custom parameters:

```bash
# Default (2 minutes from now)
node scripts/create_scheduled_notification.js

# Custom notification
node scripts/create_scheduled_notification.js \
  --title "Flash Sale!" \
  --message "50% off for the next hour!" \
  --type promo \
  --minutes 5
```

**Parameters:**
- `--title`: Notification title (default: "🎉 Special Offer!")
- `--message`: Notification message (default: "Check out our latest deals!")
- `--type`: Notification type (default: "promo")
  - Options: `promo`, `system`, `update`, `order`
- `--minutes`: Minutes from now (default: 2)
- `--target`: Target audience (default: "all")
  - Options: `all`, `user`, `segment`

**Examples:**

```bash
# Quick test (30 seconds)
node scripts/create_scheduled_notification.js --minutes 0.5

# Lunch special (in 2 hours)
node scripts/create_scheduled_notification.js \
  --title "🍔 Lunch Special!" \
  --message "Get 30% off lunch orders now!" \
  --type promo \
  --minutes 120

# System announcement (in 10 minutes)
node scripts/create_scheduled_notification.js \
  --title "🔧 Maintenance Notice" \
  --message "System maintenance in 30 minutes" \
  --type system \
  --minutes 10
```

---

### 3. List Scheduled Notifications

View all scheduled notifications and their status:

```bash
# List all notifications
node scripts/list_scheduled_notifications.js

# List only pending notifications
node scripts/list_scheduled_notifications.js --status pending

# List sent notifications
node scripts/list_scheduled_notifications.js --status sent

# List cancelled notifications
node scripts/list_scheduled_notifications.js --status cancelled
```

**Output includes:**
- 📊 Statistics (pending, sent, cancelled, failed counts)
- 📋 Detailed list of notifications with:
  - ID, title, type, status
  - Scheduled time (with relative time)
  - Target audience
  - Message preview
  - Recurring pattern (if applicable)

---

### 4. Cancel Scheduled Notification

Cancel a pending notification:

```bash
node scripts/cancel_scheduled_notification.js <notification_id>
```

**Example:**

```bash
# First, list pending notifications to get the ID
node scripts/list_scheduled_notifications.js --status pending

# Then cancel using the ID
node scripts/cancel_scheduled_notification.js 507f1f77bcf86cd799439011
```

**Note:** Only pending notifications can be cancelled.

---

## API Endpoints

You can also use the API directly:

### Create Scheduled Notification

```bash
POST /api/scheduled-notifications
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "scheduledFor": "2025-12-25T09:00:00Z",
  "type": "promo",
  "title": "Christmas Special!",
  "message": "Get 50% off today!",
  "data": {
    "promoCode": "XMAS50",
    "route": "/promos"
  },
  "targetType": "all"
}
```

### List Scheduled Notifications

```bash
GET /api/scheduled-notifications?status=pending&page=1&limit=50
Authorization: Bearer <admin_token>
```

### Get Single Notification

```bash
GET /api/scheduled-notifications/:id
Authorization: Bearer <admin_token>
```

### Update Scheduled Notification

```bash
PATCH /api/scheduled-notifications/:id
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "title": "Updated Title",
  "scheduledFor": "2025-12-26T10:00:00Z"
}
```

### Cancel Scheduled Notification

```bash
DELETE /api/scheduled-notifications/:id
Authorization: Bearer <admin_token>
```

### Get Statistics

```bash
GET /api/scheduled-notifications/stats
Authorization: Bearer <admin_token>
```

---

## How It Works

### 1. Scheduler (Cron Job)

- Runs **every minute** automatically
- Checks for notifications where `scheduledFor <= now` and `status = 'pending'`
- Sends notifications to target users
- Updates status to `'sent'` or `'failed'`
- For recurring notifications, creates next occurrence

### 2. Notification Flow

```
1. Create scheduled notification → Saved to database with status 'pending'
2. Cron job runs every minute → Finds due notifications
3. For each due notification:
   - Get target users (all, specific users, or segment)
   - Send via existing notification service
   - Update status to 'sent'
   - If recurring, create next occurrence
```

### 3. Targeting Options

**All Users:**
```json
{
  "targetType": "all"
}
```

**Specific Users:**
```json
{
  "targetType": "user",
  "targetUsers": ["user_id_1", "user_id_2"]
}
```

**User Segment:**
```json
{
  "targetType": "segment",
  "targetSegment": {
    "inactive": true,
    "daysSinceLastOrder": 7
  }
}
```

### 4. Recurring Notifications

```json
{
  "isRecurring": true,
  "recurrencePattern": {
    "frequency": "daily",
    "timeOfDay": "12:00",
    "endDate": "2025-12-31T23:59:59Z"
  }
}
```

**Frequency options:**
- `daily`: Repeats every day
- `weekly`: Repeats every week
- `monthly`: Repeats every month

---

## Testing Checklist

- [ ] Run test script and verify all 5 tests pass
- [ ] Create a notification for 1 minute from now
- [ ] Watch server logs to see it being sent
- [ ] List notifications and verify status changes
- [ ] Create a notification and cancel it
- [ ] Test API endpoints with Postman/curl
- [ ] Create a recurring notification
- [ ] Verify next occurrence is created after first sends

---

## Troubleshooting

### Notifications not sending?

1. **Check server logs** - Look for scheduler messages
2. **Verify cron is running** - Should see "Scheduler run" messages every minute
3. **Check notification status** - Use list script to see if status is still 'pending'
4. **Verify scheduled time** - Make sure it's in the future

### "Scheduled time must be in the future" error?

- The scheduled time must be at least 1 second in the future
- Check your system time is correct

### No users receiving notifications?

- Verify users exist in database with `role: 'customer'`
- Check target type is correct
- For specific users, verify user IDs are valid

---

## Next Steps

Once you build your React admin panel, you can:

1. Create a UI for the API endpoints
2. Add a calendar picker for scheduling
3. Show notification statistics dashboard
4. Add notification preview before scheduling
5. Implement user segment builder UI

The backend is ready and waiting! 🚀
