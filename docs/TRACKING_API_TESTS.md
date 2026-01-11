# GrabGo Live Tracking API Test Script

## 🎯 Test Your Deployed Backend

Replace `YOUR_RENDER_URL` with your actual Render URL (e.g., `https://grabgo-api.onrender.com`)
Replace `YOUR_AUTH_TOKEN` with a valid JWT token from your app

---

## Test 1: Health Check

```bash
curl https://YOUR_RENDER_URL/api/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "message": "GrabGo API is running"
}
```

---

## Test 2: Initialize Tracking

```bash
curl -X POST https://YOUR_RENDER_URL/api/tracking/initialize \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -d '{
    "orderId": "67819a1b2c3d4e5f6a7b8c9d",
    "riderId": "67819a1b2c3d4e5f6a7b8c9e",
    "customerId": "67819a1b2c3d4e5f6a7b8c9f",
    "pickupLocation": {
      "latitude": 5.6037,
      "longitude": -0.1870
    },
    "destination": {
      "latitude": 5.6137,
      "longitude": -0.1970
    }
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "_id": "...",
    "orderId": "67819a1b2c3d4e5f6a7b8c9d",
    "riderId": "67819a1b2c3d4e5f6a7b8c9e",
    "customerId": "67819a1b2c3d4e5f6a7b8c9f",
    "status": "preparing",
    "pickupLocation": {
      "type": "Point",
      "coordinates": [-0.1870, 5.6037]
    },
    "destination": {
      "type": "Point",
      "coordinates": [-0.1970, 5.6137]
    },
    "createdAt": "2026-01-10T19:42:00.000Z"
  }
}
```

---

## Test 3: Update Rider Location

```bash
curl -X POST https://YOUR_RENDER_URL/api/tracking/location \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -d '{
    "orderId": "67819a1b2c3d4e5f6a7b8c9d",
    "latitude": 5.6047,
    "longitude": -0.1880,
    "speed": 5.5,
    "accuracy": 10
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "distanceRemaining": 1234,
    "estimatedArrival": "2026-01-10T19:52:00.000Z",
    "status": "in_transit"
  }
}
```

---

## Test 4: Get Tracking Info

```bash
curl -X GET https://YOUR_RENDER_URL/api/tracking/67819a1b2c3d4e5f6a7b8c9d \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN"
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "_id": "...",
    "orderId": "67819a1b2c3d4e5f6a7b8c9d",
    "currentLocation": {
      "type": "Point",
      "coordinates": [-0.1880, 5.6047]
    },
    "destination": {
      "type": "Point",
      "coordinates": [-0.1970, 5.6137]
    },
    "status": "in_transit",
    "distanceRemaining": 1234,
    "estimatedArrival": "2026-01-10T19:52:00.000Z",
    "route": {
      "polyline": "encoded_polyline_string",
      "duration": 600,
      "distance": 1234
    },
    "riderId": {
      "_id": "...",
      "name": "Rider Name",
      "phone": "+233...",
      "profileImage": "..."
    }
  }
}
```

---

## Test 5: Update Order Status

```bash
curl -X PATCH https://YOUR_RENDER_URL/api/tracking/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -d '{
    "orderId": "67819a1b2c3d4e5f6a7b8c9d",
    "status": "picked_up"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "_id": "...",
    "orderId": "67819a1b2c3d4e5f6a7b8c9d",
    "status": "picked_up",
    "lastUpdated": "2026-01-10T19:45:00.000Z"
  }
}
```

---

## 🧪 Quick Test Script (Copy & Paste)

Save this as `test-tracking.sh`:

```bash
#!/bin/bash

# Configuration
API_URL="https://YOUR_RENDER_URL"
AUTH_TOKEN="YOUR_AUTH_TOKEN"

echo "🧪 Testing GrabGo Live Tracking API"
echo "===================================="
echo ""

# Test 1: Health Check
echo "1️⃣ Testing Health Check..."
curl -s "${API_URL}/api/health" | jq '.'
echo ""

# Test 2: Initialize Tracking
echo "2️⃣ Testing Initialize Tracking..."
INIT_RESPONSE=$(curl -s -X POST "${API_URL}/api/tracking/initialize" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d '{
    "orderId": "67819a1b2c3d4e5f6a7b8c9d",
    "riderId": "67819a1b2c3d4e5f6a7b8c9e",
    "customerId": "67819a1b2c3d4e5f6a7b8c9f",
    "pickupLocation": {"latitude": 5.6037, "longitude": -0.1870},
    "destination": {"latitude": 5.6137, "longitude": -0.1970}
  }')

echo "$INIT_RESPONSE" | jq '.'
echo ""

# Test 3: Update Location
echo "3️⃣ Testing Update Location..."
curl -s -X POST "${API_URL}/api/tracking/location" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d '{
    "orderId": "67819a1b2c3d4e5f6a7b8c9d",
    "latitude": 5.6047,
    "longitude": -0.1880,
    "speed": 5.5,
    "accuracy": 10
  }' | jq '.'
echo ""

# Test 4: Get Tracking Info
echo "4️⃣ Testing Get Tracking Info..."
curl -s -X GET "${API_URL}/api/tracking/67819a1b2c3d4e5f6a7b8c9d" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" | jq '.'
echo ""

echo "✅ All tests completed!"
```

---

## 🔍 Common Errors & Solutions

### Error: "Not authorized, no token provided"
**Solution:** Make sure you're sending the Authorization header with a valid JWT token

### Error: "Tracking not found"
**Solution:** Use a valid orderId that exists in your database

### Error: "Invalid coordinates"
**Solution:** Ensure latitude is between -90 and 90, longitude between -180 and 180

### Error: "Google Maps API error"
**Solution:** 
1. Check GOOGLE_MAPS_API_KEY is set in Render environment variables
2. Verify the API key is valid
3. Ensure billing is enabled in Google Cloud Console

---

## 📊 What to Check

After testing, verify:

- ✅ Tracking document created in MongoDB
- ✅ Socket.IO events emitted (check server logs)
- ✅ ETA calculated correctly
- ✅ Distance calculated
- ✅ Route polyline generated
- ✅ Geofencing triggers (when within 50m of restaurant or 100m of customer)
- ✅ Push notifications sent

---

## 🎉 Success Indicators

Your tracking is working if you see:

1. **Status 201** on initialize
2. **Status 200** on location update
3. **Valid ETA** in response
4. **Route polyline** in tracking info
5. **Socket.IO logs** in Render logs
6. **MongoDB documents** being created/updated

---

**Ready to test? Let me know what you need!** 🚀
