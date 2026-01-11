# Live Order Tracking - Real Device Testing Guide

## 🎯 Testing Strategy

You'll need **2 physical devices** (or 1 device + 1 emulator) to test the complete tracking flow.

---

## 📱 Setup: 2 Devices Required

### Device 1: **Rider App** (Your Friend)
- **Role:** Delivery rider
- **Account Type:** Rider account
- **What they do:** Move around with GPS on

### Device 2: **Customer App** (You)
- **Role:** Customer ordering food
- **Account Type:** Customer account
- **What you do:** Watch the rider's location in real-time

---

## 🚀 Step-by-Step Testing Process

### **Phase 1: Preparation (5 minutes)**

#### 1. Create Test Accounts

**Customer Account (You):**
```
Email: customer@test.com
Password: Test@123
Role: customer
```

**Rider Account (Your Friend):**
```
Email: rider@test.com
Password: Test@123
Role: rider
```

#### 2. Install Apps on Both Devices
- Install GrabGo Customer App on your phone
- Install GrabGo Rider App on your friend's phone
- Both devices must have **GPS enabled**
- Both devices must have **internet connection**

#### 3. Login
- You: Login to Customer App
- Friend: Login to Rider App

---

### **Phase 2: Create Test Order (2 minutes)**

#### 1. Place an Order (Customer App - You)
1. Open Customer App
2. Browse restaurants
3. Add items to cart
4. Place order with a **real delivery address**
5. Complete payment (use test mode if available)
6. **Note the Order ID**

#### 2. Accept Order (Rider App - Friend)
1. Friend opens Rider App
2. Sees the new order notification
3. Accepts the order
4. **Tracking automatically initializes!**

---

### **Phase 3: Live Tracking Test (15-30 minutes)**

#### **Scenario 1: Restaurant Pickup**

**Friend (Rider):**
1. Opens the order details
2. Clicks "Start Delivery"
3. App starts sending GPS location every 5-10 seconds
4. Walks/drives to the "restaurant" (can be any location)

**You (Customer):**
1. Opens order details
2. Sees live map with rider's location
3. Watches rider marker move in real-time
4. Sees ETA updating
5. Sees distance decreasing

**What to verify:**
- ✅ Rider marker appears on map
- ✅ Marker moves as rider moves
- ✅ Route polyline shows path
- ✅ ETA updates every 5-10 seconds
- ✅ Distance remaining decreases

---

#### **Scenario 2: Geofencing Test (Restaurant Arrival)**

**Friend (Rider):**
1. Walks to within **50 meters** of the "restaurant" location
2. Stays there for a few seconds

**You (Customer):**
1. Should receive notification: **"Rider has arrived at restaurant"**
2. Order status changes to **"Preparing"** or **"Picked Up"**
3. Map updates to show rider at restaurant

**What to verify:**
- ✅ Geofence triggers when within 50m
- ✅ Push notification received
- ✅ Status auto-updates
- ✅ No manual status change needed

---

#### **Scenario 3: Order Pickup**

**Friend (Rider):**
1. Clicks "Order Picked Up" button
2. Starts moving toward delivery location (your address)

**You (Customer):**
1. Receives notification: **"Your order is on the way!"**
2. Status changes to **"In Transit"**
3. Sees updated ETA
4. Watches rider approaching

**What to verify:**
- ✅ Status updates to "In Transit"
- ✅ Push notification sent
- ✅ Route recalculates to delivery address
- ✅ ETA shows time to your location

---

#### **Scenario 4: Delivery Approach (Nearby)**

**Friend (Rider):**
1. Walks to within **100 meters** of your delivery address
2. Continues approaching

**You (Customer):**
1. Receives notification: **"Rider arriving soon! Please be ready."**
2. Status changes to **"Nearby"**
3. ETA shows < 2 minutes
4. Can see rider very close on map

**What to verify:**
- ✅ "Nearby" geofence triggers at 100m
- ✅ Push notification received
- ✅ Status auto-updates to "Nearby"
- ✅ ETA shows imminent arrival

---

#### **Scenario 5: Delivery Completion**

**Friend (Rider):**
1. Arrives at your location
2. Hands you the "order" (can be anything for testing)
3. Clicks "Mark as Delivered"
4. Takes delivery photo (optional)

**You (Customer):**
1. Receives notification: **"Order delivered! Enjoy your meal!"**
2. Status changes to **"Delivered"**
3. Tracking stops
4. Can rate the rider

**What to verify:**
- ✅ Status updates to "Delivered"
- ✅ Tracking stops
- ✅ Location updates stop
- ✅ Final notification received

---

## 🧪 Alternative Testing Methods

### **Option 1: Solo Testing (1 Device)**

If you don't have a friend available:

1. **Use Android Emulator + Real Phone:**
   - Emulator: Customer App
   - Real Phone: Rider App (you walk around)
   
2. **Use GPS Spoofing (Development Only):**
   - Install GPS spoofing app on rider device
   - Simulate movement along a route
   - ⚠️ **Only for testing, not production!**

---

### **Option 2: Desktop + Mobile Testing**

1. **Desktop Browser:** Customer view (using Flutter Web)
2. **Mobile Phone:** Rider app (you walk around)
3. Watch the desktop screen while moving with phone

---

### **Option 3: Two Phones, One Person**

1. **Phone 1 (Rider App):** Place in your car/bag
2. **Phone 2 (Customer App):** Hold and watch
3. Drive/walk around and monitor both

---

## 📍 Recommended Test Routes

### **Short Test (5-10 minutes)**
```
Start: Your current location
Pickup: Coffee shop 500m away
Delivery: Back to your location
```

### **Medium Test (15-20 minutes)**
```
Start: Your home
Pickup: Restaurant 2km away
Delivery: Friend's house 3km away
```

### **Full Test (30+ minutes)**
```
Start: Your location
Pickup: Actual restaurant
Delivery: Real address across town
```

---

## ✅ Testing Checklist

### Before Testing
- [ ] Both devices have GPS enabled
- [ ] Both devices have internet connection
- [ ] Both apps are installed and logged in
- [ ] Test accounts created (customer + rider)
- [ ] Backend is running on Render
- [ ] Google Maps API key is configured

### During Testing
- [ ] Location permissions granted on both devices
- [ ] Rider app sends location updates
- [ ] Customer app receives updates
- [ ] Map displays correctly
- [ ] Route polyline shows
- [ ] ETA updates in real-time
- [ ] Distance decreases as rider approaches
- [ ] Geofencing triggers at correct distances
- [ ] Push notifications received
- [ ] Status changes automatically

### After Testing
- [ ] All statuses updated correctly
- [ ] Tracking data saved in database
- [ ] No crashes or errors
- [ ] Battery usage acceptable
- [ ] Network usage reasonable

---

## 🐛 Common Issues & Solutions

### Issue: "Location not updating"
**Solution:**
- Check GPS is enabled
- Ensure app has location permission
- Verify internet connection
- Check Render logs for errors

### Issue: "Rider not visible on map"
**Solution:**
- Refresh customer app
- Check Socket.IO connection
- Verify rider started tracking
- Check order ID matches

### Issue: "Geofencing not triggering"
**Solution:**
- Ensure GPS accuracy < 20 meters
- Walk closer (within 50m for restaurant, 100m for delivery)
- Wait 10-15 seconds for update
- Check backend logs

### Issue: "High battery drain"
**Solution:**
- Reduce update frequency (10s → 15s)
- Implement adaptive tracking
- Use distance filter (only update when moved 10m+)

---

## 📊 What to Monitor

### On Rider Device
- GPS accuracy
- Battery usage
- Network data usage
- App performance
- Location update frequency

### On Customer Device
- Map rendering
- Marker updates
- Route display
- ETA accuracy
- Notification delivery

### On Backend (Render Logs)
- Location update requests
- Socket.IO events
- Google Maps API calls
- Database writes
- Error logs

---

## 🎯 Success Criteria

Your tracking is working perfectly if:

1. ✅ **Real-time Updates:** Customer sees rider move within 5-10 seconds
2. ✅ **Accurate Location:** Rider position matches actual location (< 20m error)
3. ✅ **Smooth Movement:** Marker moves smoothly, not jumping
4. ✅ **Correct ETA:** ETA matches actual arrival time (±2 minutes)
5. ✅ **Route Display:** Polyline shows actual road path
6. ✅ **Auto-Status:** Geofencing triggers status changes automatically
7. ✅ **Notifications:** Push notifications arrive within 2-3 seconds
8. ✅ **Performance:** No lag, crashes, or excessive battery drain

---

## 💡 Pro Testing Tips

1. **Start Small:** Test in a small area first (walking distance)
2. **Use WiFi:** Test on WiFi before testing on mobile data
3. **Check Logs:** Monitor Render logs during testing
4. **Take Screenshots:** Document the tracking working
5. **Test Edge Cases:**
   - Poor GPS signal (indoors)
   - Poor network (underground)
   - App backgrounded
   - Phone locked
   - Low battery

---

## 🎬 Testing Script

Here's a complete testing script you can follow:

```
Time: 0:00 - Customer places order
Time: 0:30 - Rider accepts order
Time: 1:00 - Rider starts tracking
Time: 2:00 - Rider moves toward restaurant
Time: 5:00 - Rider arrives at restaurant (geofence triggers)
Time: 6:00 - Rider picks up order
Time: 7:00 - Rider starts delivery
Time: 12:00 - Rider gets within 100m (nearby geofence)
Time: 15:00 - Rider arrives at delivery location
Time: 15:30 - Rider marks as delivered
Time: 16:00 - Customer rates delivery
```

---

## 📹 Record Your Test

**Recommended:**
1. Screen record both devices
2. Take photos of key moments
3. Note timestamps
4. Document any issues
5. Share with your team

---

**Ready to test? Get a friend, grab two phones, and let's see your tracking in action!** 🚀

**Questions to ask yourself after testing:**
- Did it feel like Uber Eats?
- Would you trust this for real deliveries?
- What needs improvement?

Good luck with your testing! 🎉
