# Real-Time Notification Testing Guide

## 🚀 Server is Running!

The server is now running with test endpoints that trigger real-time WebSocket notifications.

---

## 📱 How to Test

### Step 1: Open Your App
1. Open the GrabGo customer app
2. Login with: `zakjnr5@gmail.com`
3. Navigate to the **Notifications** screen
4. **Keep the app open** on this screen

### Step 2: Trigger a Test Notification

Open a new terminal/PowerShell and run ONE of these commands:

#### Test 1: Simple Test Notification
```powershell
curl -X POST http://localhost:5000/api/test/notification `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer YOUR_TOKEN_HERE" `
  -d '{}'
```

#### Test 2: Order Confirmed Notification
```powershell
curl -X POST http://localhost:5000/api/test/order-notification `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer YOUR_TOKEN_HERE" `
  -d '{"status": "confirmed"}'
```

#### Test 3: Order Preparing Notification
```powershell
curl -X POST http://localhost:5000/api/test/order-notification `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer YOUR_TOKEN_HERE" `
  -d '{"status": "preparing"}'
```

#### Test 4: Order Ready Notification
```powershell
curl -X POST http://localhost:5000/api/test/order-notification `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer YOUR_TOKEN_HERE" `
  -d '{"status": "ready"}'
```

#### Test 5: Referral Notification
```powershell
curl -X POST http://localhost:5000/api/test/referral-notification `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer YOUR_TOKEN_HERE" `
  -d '{}'
```

---

## 🔑 Getting Your Auth Token

### Option 1: From App (Easiest)
1. Login to the app
2. The token is stored in secure storage
3. You can print it in the app's debug console

### Option 2: Login via API
```powershell
curl -X POST http://localhost:5000/api/users/login `
  -H "Content-Type: application/json" `
  -d '{
    "email": "zakjnr5@gmail.com",
    "password": "YOUR_PASSWORD"
  }'
```

Copy the `token` from the response and use it in the commands above.

---

## ✅ What to Expect

When you run the curl command:

1. **Instantly** (within 1 second):
   - A new notification should appear in the app
   - **WITHOUT** needing to pull-to-refresh
   - **WITHOUT** closing and reopening the app

2. The notification will have:
   - Correct emoji and title
   - Correct message
   - Timestamp showing "just now"

3. Server logs will show:
   ```
   📡 Real-time notification emitted to user {userId}
   ```

---

## 🧪 Test All Order Statuses

Run these one by one and watch them appear instantly:

```powershell
# 1. Confirmed
curl -X POST http://localhost:5000/api/test/order-notification -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" -d '{"status":"confirmed"}'

# 2. Preparing  
curl -X POST http://localhost:5000/api/test/order-notification -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" -d '{"status":"preparing"}'

# 3. Ready
curl -X POST http://localhost:5000/api/test/order-notification -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" -d '{"status":"ready"}'

# 4. Picked Up
curl -X POST http://localhost:5000/api/test/order-notification -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" -d '{"status":"picked_up"}'

# 5. On the Way
curl -X POST http://localhost:5000/api/test/order-notification -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" -d '{"status":"on_the_way"}'

# 6. Delivered
curl -X POST http://localhost:5000/api/test/order-notification -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" -d '{"status":"delivered"}'
```

Replace `TOKEN` with your actual auth token.

---

## 🐛 Troubleshooting

### Notification doesn't appear instantly
- Check if app is connected to Socket.IO (check app logs)
- Verify server logs show "📡 Real-time notification emitted"
- Make sure you're on the notifications screen

### "Unauthorized" error
- Your token is invalid or expired
- Login again to get a new token

### Server not responding
- Check if server is still running: `http://localhost:5000/api/health`
- Restart server if needed

---

## 🎯 Success Criteria

✅ Notification appears **instantly** without refresh  
✅ Correct emoji and message  
✅ Server logs show WebSocket emission  
✅ Multiple notifications can be triggered in sequence  
✅ All appear without any manual refresh

---

## 📝 Alternative: Use Postman

1. Open Postman
2. Create new POST request
3. URL: `http://localhost:5000/api/test/order-notification`
4. Headers:
   - `Content-Type`: `application/json`
   - `Authorization`: `Bearer YOUR_TOKEN`
5. Body (raw JSON):
   ```json
   {
     "status": "confirmed"
   }
   ```
6. Click Send
7. Watch notification appear in app instantly!

---

## 🎉 Next Steps

Once you confirm real-time delivery works:
1. Test with actual order flow
2. Test referral notifications
3. Deploy to production
4. Celebrate! 🎊
