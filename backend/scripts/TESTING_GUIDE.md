# Notification Testing Guide

## Quick Start

### 1. Test Order Status Notifications
```bash
# Update the test user email in the script first
node backend/scripts/test_order_notifications.js
```

**What it tests:**
- ✅ Order Confirmed
- 🍳 Preparing
- 📦 Ready for Pickup
- 🚴 Picked Up
- 🛣️ On the Way
- ✅ Delivered

**Expected Result:**
- 6 notifications created in database
- All notifications appear in app instantly (if app is open)
- No manual refresh needed

---

### 2. Test Referral Notifications
```bash
# Update the referrer/referee emails in the script first
node backend/scripts/test_referral_notifications.js
```

**What it tests:**
- 🎉 Referral completion notification
- 🎊 Milestone bonus (if 5th, 10th, 15th referral)

**Expected Result:**
- Referral completion notification appears
- If milestone reached, bonus notification appears
- Both appear instantly without refresh

---

## Configuration

### test_order_notifications.js
```javascript
const TEST_USER_EMAIL = 'test@example.com'; // Change to your test user
```

### test_referral_notifications.js
```javascript
const REFERRER_EMAIL = 'referrer@example.com'; // User receiving notifications
const REFEREE_EMAIL = 'referee@example.com';   // User completing order
```

---

## Manual Testing (Alternative)

### Order Notifications
1. Place an order via the app
2. Use admin panel or MongoDB to change order status
3. Watch notifications appear in real-time

### Referral Notifications
1. Create referral code for User A
2. User B signs up with code
3. User B places first order (GHS 20+)
4. User A receives notification instantly

---

## Verification Checklist

### In the App
- [ ] Notifications appear without refresh
- [ ] Correct emoji and title
- [ ] Correct message text
- [ ] Tapping notification navigates correctly
- [ ] Notifications persist after app restart

### In MongoDB
```javascript
// Check notifications were created
db.notifications.find({ user: ObjectId("USER_ID") }).sort({ createdAt: -1 })

// Check notification has correct data
{
  type: "order_update",
  title: "✅ Order #12345",
  message: "Your order has been confirmed!",
  data: {
    orderId: "...",
    orderNumber: "12345",
    status: "confirmed",
    route: "/orders/..."
  }
}
```

### In Server Logs
Look for:
```
✅ Socket.IO singleton initialized
📡 Real-time notification emitted to user 123abc
✅ Referral notifications sent to 456def
```

---

## Troubleshooting

### Notifications not appearing in real-time
- Check Socket.IO connection in app
- Verify server logs show "📡 Real-time notification emitted"
- Check user is in correct room: `user:${userId}`

### Notifications not in database
- Check for errors in server logs
- Verify `createNotification` was called
- Check MongoDB connection

### Script errors
- Ensure MongoDB is running
- Update test user emails to existing users
- Check `.env` file has correct `MONGODB_URI`

---

## Cleanup

### Delete Test Data
```javascript
// Delete test order
db.orders.deleteOne({ orderNumber: "TEST-1234567890" })

// Delete test notifications
db.notifications.deleteMany({ 
  user: ObjectId("USER_ID"),
  createdAt: { $gte: new Date("2025-12-20") }
})

// Delete test referral
db.referrals.deleteOne({ _id: ObjectId("REFERRAL_ID") })
```

---

## Success Criteria

✅ All 6 order status notifications appear in app  
✅ Notifications appear instantly without refresh  
✅ Referral completion notification works  
✅ Milestone bonus notification works (if applicable)  
✅ No errors in server logs  
✅ Notifications persist in database  
✅ Tapping notifications navigates correctly
