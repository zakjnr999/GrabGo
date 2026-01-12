# Testing Live Tracking Without Rider App

## 🧪 Test Mode Overview

We've created a **mock tracking system** that simulates a rider delivering your order without needing the actual rider app. This is perfect for testing the UI and flow before the rider app is ready.

---

## 🚀 Quick Start

### Option 1: Use the Test Page (Easiest)

1. Navigate to `TrackingTestPage`:
```dart
import 'package:grab_go_customer/features/order/view/tracking_test_page.dart';

// In your navigation:
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => TrackingTestPage()),
);
```

2. Tap "Start Test" button
3. Watch the simulation!

### Option 2: Direct Navigation

Navigate directly to the tracking screen with test mode enabled:

```dart
import 'package:grab_go_customer/features/order/view/map_tracking.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MapTracking(
      orderId: 'test_order_123',
      useTestMode: true, // ← Enable test mode
    ),
  ),
);
```

---

## 📋 What the Simulation Does

### Timeline:

| Time | Event | What You'll See |
|------|-------|-----------------|
| **0s** | Order Accepted | Progress bar at step 0 |
| **10s** | Preparing | Progress bar moves to step 1 |
| **20s** | Rider Picks Up | Progress bar at step 2, rider marker appears |
| **20-80s** | Rider Moving | Rider marker moves towards destination, ETA & distance update |
| **80s** | Delivered | Progress bar at step 3, simulation ends |

### Real-Time Updates:

✅ **Map markers** - Rider, restaurant, and destination  
✅ **Polyline** - Route from rider to you  
✅ **ETA** - Updates as rider moves  
✅ **Distance** - Decreases as rider approaches  
✅ **Status** - Changes from "Preparing" → "On The Way" → "Delivered"  
✅ **Progress bar** - Animates through all steps  

---

## 🎯 Testing Checklist

Use this to verify everything works:

- [ ] Map loads correctly
- [ ] Rider marker appears
- [ ] Destination marker appears
- [ ] Restaurant marker appears
- [ ] Polyline shows route
- [ ] Progress bar starts at "Accepted"
- [ ] After 10s: Status changes to "Preparing"
- [ ] After 20s: Status changes to "On The Way"
- [ ] Rider marker moves smoothly
- [ ] ETA updates (decreases over time)
- [ ] Distance updates (decreases over time)
- [ ] After 80s: Status changes to "Delivered"
- [ ] Progress bar reaches final step
- [ ] Rider name shows "Test Rider"
- [ ] Rating shows "4.8"
- [ ] No crashes or errors

---

## 🔧 Customizing the Test

### Change Simulation Speed

Edit `mock_tracking_service.dart`:

```dart
// Current: Updates every 5 seconds
Timer.periodic(const Duration(seconds: 5), (timer) {

// Faster: Updates every 2 seconds
Timer.periodic(const Duration(seconds: 2), (timer) {
```

### Change Locations

Edit `mock_tracking_service.dart`:

```dart
// Current locations (Accra)
LatLng _currentLocation = const LatLng(5.6037, -0.1870);
final LatLng _destination = const LatLng(5.6150, -0.1950);

// Change to your preferred locations
LatLng _currentLocation = const LatLng(YOUR_LAT, YOUR_LNG);
final LatLng _destination = const LatLng(DEST_LAT, DEST_LNG);
```

### Change Rider Info

Edit `mock_tracking_service.dart`:

```dart
rider: RiderInfo(
  id: 'mock_rider_123',
  name: 'Your Test Rider Name', // ← Change this
  phone: '+233123456789',
  rating: 4.8, // ← Change this
),
```

---

## 🔄 Switching to Real Mode

When your rider app is ready:

### Option 1: Remove Test Mode Parameter

```dart
// Before (Test Mode):
MapTracking(
  orderId: actualOrderId,
  useTestMode: true,
)

// After (Real Mode):
MapTracking(
  orderId: actualOrderId,
  // useTestMode defaults to false
)
```

### Option 2: Conditional Based on Environment

```dart
MapTracking(
  orderId: actualOrderId,
  useTestMode: kDebugMode, // Test in debug, real in release
)
```

---

## 🐛 Troubleshooting

### Map doesn't show
- Check Google Maps API key is configured
- Verify internet connection

### Rider doesn't move
- Check console for "🧪 Mock update received" messages
- Verify simulation timer is running

### No updates after 80 seconds
- This is expected - simulation ends at delivery
- Restart the test to see it again

---

## 📝 Console Output

You should see these logs:

```
🧪 TEST MODE: Using mock tracking provider
🧪 Creating MockTrackingProvider
🧪 Starting mock tracking simulation for order: test_order_123
📦 Status: Preparing
🚴 Status: Picked up - Rider starting journey
📍 Rider moving... 1.35 km remaining
📍 Rider moving... 1.21 km remaining
...
✅ Status: Delivered!
🛑 Mock tracking simulation stopped
```

---

## ✅ Ready to Test!

1. Run your app
2. Navigate to `TrackingTestPage`
3. Tap "Start Test"
4. Watch the magic happen! ✨

**No rider app needed!** 🎉
