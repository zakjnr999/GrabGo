# 🧪 WebRTC Testing Guide

## Quick Start - Testing Without Rider App

You have **2 options** to test the WebRTC calling feature without the rider app:

---

## ✅ Option 1: Browser Test Client (RECOMMENDED)

### Setup (30 seconds)

1. **Open the test client**:
   ```bash
   # Navigate to the test file
   cd /home/zakjnr/Documents/Project/GrabGo/backend/test
   
   # Open in browser (choose one):
   google-chrome webrtc-test-client.html
   # OR
   firefox webrtc-test-client.html
   # OR just double-click the file
   ```

2. **Configure the test client**:
   - **Backend URL**: `https://grabgo-backend.onrender.com`
   - **Rider ID**: `test-rider-123` (or any ID)
   - **JWT Token**: Leave empty for testing OR paste a real rider token

3. **Click "Connect as Rider"**

4. **You're ready!** The test client will:
   - ✅ Connect to your backend
   - ✅ Register as a rider
   - ✅ Wait for incoming calls
   - ✅ Show answer/reject buttons when call comes in
   - ✅ Establish WebRTC connection
   - ✅ Handle audio streams

---

## 🧪 Testing Flow

### Test 1: Basic Call Flow

**Step 1**: Start the browser test client
```
1. Open webrtc-test-client.html
2. Click "Connect as Rider"
3. Wait for "Connected - Waiting for calls"
```

**Step 2**: Start your customer app
```
1. Run: flutter run
2. Navigate to map tracking page
3. Tap the call button (phone icon)
```

**Step 3**: In the browser test client
```
1. You'll see "INCOMING CALL!" 
2. Click "Answer Call"
3. Wait for "Call Active"
```

**Step 4**: Verify in customer app
```
✅ Call screen should show "Active"
✅ Duration timer should start
✅ Mute button should work
✅ Speaker button should work
✅ End call button should work
```

**Step 5**: End the call
```
Option A: Click "End Call" in customer app
Option B: Click "End Call" in browser test client
```

---

### Test 2: Call Rejection

**In browser test client**:
1. Wait for incoming call
2. Click "Reject Call"

**In customer app**:
- ✅ Should show "Call rejected"
- ✅ Should close call screen

---

### Test 3: Call Timeout

**In customer app**:
1. Initiate call
2. Don't answer in test client
3. Wait 30 seconds

**Expected**:
- ✅ Call should timeout
- ✅ Call screen should close
- ✅ Backend should log timeout

---

### Test 4: Multiple Calls

**Test blocking**:
1. Start a call
2. Try to start another call
3. Should be blocked with message

---

## 📊 What to Check

### In Customer App
- [ ] Call screen opens
- [ ] Shows "Connecting..."
- [ ] Shows "Ringing..."
- [ ] Shows "Active" when answered
- [ ] Duration timer works
- [ ] Mute button toggles
- [ ] Speaker button toggles
- [ ] End call closes screen
- [ ] Audio works (if using real mic)

### In Browser Test Client
- [ ] Connects to backend
- [ ] Receives incoming call
- [ ] Shows caller info
- [ ] Answer button works
- [ ] Reject button works
- [ ] End call button works
- [ ] Logs show all events
- [ ] Connection state updates

### In Backend Logs
- [ ] Socket connections
- [ ] WebRTC events
- [ ] Call state changes
- [ ] ICE candidates
- [ ] Call logs saved to DB

---

## 🐛 Troubleshooting

### Browser Test Client Won't Connect

**Problem**: "Connection Failed"

**Solutions**:
1. Check backend is running
2. Check backend URL is correct
3. Check CORS settings
4. Try without JWT token first
5. Check browser console for errors

---

### No Incoming Call in Test Client

**Problem**: Customer app calls but test client doesn't receive

**Solutions**:
1. Check test client shows "Connected"
2. Check rider ID matches
3. Check backend logs for events
4. Refresh browser and reconnect
5. Check Socket.IO connection

---

### Call Connects But No Audio

**Problem**: Call is active but can't hear anything

**Solutions**:
1. Check microphone permissions in browser
2. Check microphone permissions in Flutter app
3. Check speaker is not muted
4. Check TURN server is working
5. Check ICE candidates are exchanged

---

### Call Fails to Connect

**Problem**: Stuck on "Connecting..."

**Solutions**:
1. Check TURN server credentials
2. Check ICE candidates in logs
3. Check firewall settings
4. Try different network
5. Check peer connection state

---

## 📱 Testing on Real Devices

### Android
```bash
# Connect device
adb devices

# Run app
flutter run

# View logs
flutter logs
```

### iOS
```bash
# Run on simulator
flutter run

# Or on device
flutter run -d <device-id>
```

---

## 🔍 Debugging Tips

### Enable Verbose Logging

**In Flutter**:
```dart
// In webrtc_service.dart, all debugPrint statements are already there
// Just watch the console
```

**In Browser Test Client**:
- All logs appear in the UI
- Also check browser DevTools console (F12)

**In Backend**:
```javascript
// Already has console.log for all events
// Just watch the terminal
```

---

### Check WebRTC Stats

**In Browser (F12 Console)**:
```javascript
// Get peer connection stats
peerConnection.getStats().then(stats => {
  stats.forEach(report => {
    console.log(report);
  });
});
```

---

### Monitor Network Traffic

**In Browser**:
1. Open DevTools (F12)
2. Go to Network tab
3. Filter by "WS" (WebSocket)
4. Watch Socket.IO messages

---

## 🎯 Success Criteria

Your implementation is working if:

✅ **Connection**
- Test client connects to backend
- Customer app connects to backend
- Both show "Connected" status

✅ **Call Initiation**
- Customer can tap call button
- Test client receives incoming call
- Call ID is generated

✅ **Call Answering**
- Test client can answer
- Customer app shows "Active"
- Duration timer starts

✅ **Audio**
- Can hear audio (if using real mic)
- Mute button works
- Speaker button works

✅ **Call Ending**
- Either party can end call
- Call screen closes
- Resources cleaned up

✅ **Error Handling**
- Rejection works
- Timeout works
- Network errors handled
- UI updates correctly

---

## 📝 Test Checklist

### Before Testing
- [ ] Backend server running
- [ ] Redis running (optional)
- [ ] Flutter app compiled
- [ ] Test client ready
- [ ] Microphone available

### During Testing
- [ ] Test all call states
- [ ] Test all buttons
- [ ] Test error scenarios
- [ ] Check logs
- [ ] Monitor performance

### After Testing
- [ ] Review logs
- [ ] Check database
- [ ] Verify cleanup
- [ ] Document issues
- [ ] Plan fixes

---

## 🚀 Next Steps After Testing

### If Everything Works
1. ✅ Mark feature as complete
2. 📝 Document any quirks
3. 🎨 Polish UI if needed
4. 📱 Test on more devices
5. 🚀 Deploy to production

### If Issues Found
1. 🐛 Document the bug
2. 📊 Check logs
3. 🔍 Debug step by step
4. 🔧 Fix the issue
5. ✅ Re-test

---

## 💡 Pro Tips

### Tip 1: Use Two Browsers
- Open test client in Chrome
- Open another in Firefox
- Test multiple calls

### Tip 2: Use Browser DevTools
- Monitor WebRTC stats
- Check ICE candidates
- View network traffic
- Debug JavaScript

### Tip 3: Test on Mobile
- Use Chrome Remote Debugging
- Test on real devices
- Check mobile networks
- Test with poor connection

### Tip 4: Monitor Backend
- Watch backend logs in real-time
- Check Redis (if using)
- Monitor database
- Check memory usage

---

## 📞 Support

If you encounter issues:

1. **Check the logs** (customer app, test client, backend)
2. **Review the documentation** (implementation guides)
3. **Test step by step** (isolate the problem)
4. **Check network** (firewall, NAT, TURN server)

---

## 🎉 You're Ready!

Open `webrtc-test-client.html` in your browser and start testing! 🚀

The test client is **fully interactive** and will guide you through the process.

---

**Happy Testing!** 🧪✨
